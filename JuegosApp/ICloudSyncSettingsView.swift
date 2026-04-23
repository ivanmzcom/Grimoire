//
//  ICloudSyncSettingsView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import Foundation

enum AppCloudKitConfiguration {
    static let containerIdentifier = "iCloud.com.ivanmz.JuegosApp"
}

#if os(macOS)
import CloudKit
import Combine
import CoreData
import SwiftUI

struct JuegosSettingsView: View {
    var body: some View {
        TabView {
            ICloudSyncSettingsView(containerIdentifier: AppCloudKitConfiguration.containerIdentifier)
                .tabItem {
                    Label("iCloud", systemImage: "icloud")
                }

            IGDBSettingsView()
                .tabItem {
                    Label("IGDB", systemImage: "magnifyingglass")
                }
        }
        .frame(width: 560, height: 430)
        .scenePadding()
    }
}

private struct ICloudSyncSettingsView: View {
    @StateObject private var statusModel: ICloudSyncStatusModel

    init(containerIdentifier: String) {
        _statusModel = StateObject(wrappedValue: ICloudSyncStatusModel(containerIdentifier: containerIdentifier))
    }

    var body: some View {
        Form {
            Section("Cuenta") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: statusModel.accountState.systemImage)
                        .font(.title2)
                        .foregroundStyle(statusModel.accountState.tint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusModel.accountState.title)
                            .font(.headline)

                        Text(statusModel.accountState.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    if statusModel.isChecking {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Comprobando iCloud")
                    }
                }

                Button("Comprobar ahora") {
                    statusModel.refreshAccountStatus()
                }
                .disabled(statusModel.isChecking)
            }

            Section("Sincronización") {
                LabeledContent("Estado", value: statusModel.syncSummary)

                if let lastEvent = statusModel.latestEvent {
                    LabeledContent("Última actividad") {
                        SyncEventSummary(event: lastEvent)
                    }
                } else {
                    LabeledContent("Última actividad", value: "Sin eventos en esta sesión")
                }

                if let lastChecked = statusModel.lastChecked {
                    LabeledContent("Última comprobación") {
                        Text(lastChecked, format: .dateTime.day().month().year().hour().minute().second())
                    }
                }
            }

            Section("Configuración") {
                LabeledContent("Container", value: statusModel.containerIdentifier)
                LabeledContent("Base de datos", value: "Privada")
            }

            Section("Actividad reciente") {
                if statusModel.recentEvents.isEmpty {
                    Text("SwiftData todavía no ha publicado eventos de importación o exportación en esta sesión.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(statusModel.recentEvents) { event in
                        SyncEventRow(event: event)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            statusModel.refreshAccountStatus()
        }
    }
}

private struct SyncEventSummary: View {
    let event: ICloudSyncEvent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: event.systemImage)
                .foregroundStyle(event.tint)

            Text(event.summary)
        }
    }
}

private struct SyncEventRow: View {
    let event: ICloudSyncEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.systemImage)
                .foregroundStyle(event.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.typeLabel)
                        .font(.body)

                    Spacer()

                    Text(event.statusLabel)
                        .font(.caption)
                        .foregroundStyle(event.tint)
                }

                Text(event.dateRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = event.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private final class ICloudSyncStatusModel: ObservableObject {
    @Published private(set) var accountState: ICloudAccountState = .checking
    @Published private(set) var recentEvents = [ICloudSyncEvent]()
    @Published private(set) var lastChecked: Date?
    @Published private(set) var isChecking = false

    let containerIdentifier: String

    private let container: CKContainer
    private var accountObserver: NSObjectProtocol?
    private var eventObserver: NSObjectProtocol?

    init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
        self.container = CKContainer(identifier: containerIdentifier)

        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccountStatus()
        }

        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.recordSyncEvent(from: notification)
        }
    }

    deinit {
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }

        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    var latestEvent: ICloudSyncEvent? {
        recentEvents.first
    }

    var syncSummary: String {
        if let latestEvent {
            return latestEvent.statusLabel
        }

        return accountState == .available ? "Preparada" : "En espera"
    }

    func refreshAccountStatus() {
        guard !isChecking else { return }

        isChecking = true
        accountState = .checking

        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self else { return }

                self.lastChecked = Date.now
                self.isChecking = false

                if let error {
                    self.accountState = .failed(error.localizedDescription)
                } else {
                    self.accountState = ICloudAccountState(status)
                }
            }
        }
    }

    private func recordSyncEvent(from notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        let syncEvent = ICloudSyncEvent(event: event)

        if let existingIndex = recentEvents.firstIndex(where: { $0.id == syncEvent.id }) {
            recentEvents[existingIndex] = syncEvent
        } else {
            recentEvents.insert(syncEvent, at: 0)
        }

        recentEvents = Array(recentEvents.prefix(8))
    }
}

private enum ICloudAccountState: Equatable {
    case checking
    case available
    case restricted
    case noAccount
    case temporarilyUnavailable
    case couldNotDetermine
    case failed(String)

    init(_ status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .restricted:
            self = .restricted
        case .noAccount:
            self = .noAccount
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }

    var title: String {
        switch self {
        case .checking:
            "Comprobando iCloud"
        case .available:
            "iCloud disponible"
        case .restricted:
            "iCloud restringido"
        case .noAccount:
            "Sin cuenta de iCloud"
        case .temporarilyUnavailable:
            "iCloud no está listo"
        case .couldNotDetermine:
            "No se pudo determinar"
        case .failed:
            "Error al comprobar iCloud"
        }
    }

    var message: String {
        switch self {
        case .checking:
            "Consultando el estado de la cuenta de iCloud."
        case .available:
            "La cuenta puede usar CloudKit y la biblioteca se sincroniza mediante SwiftData."
        case .restricted:
            "El acceso a iCloud está bloqueado por restricciones del sistema o de gestión del dispositivo."
        case .noAccount:
            "Inicia sesión en iCloud para activar la sincronización entre dispositivos."
        case .temporarilyUnavailable:
            "La cuenta existe, pero CloudKit aún no está preparado para aceptar operaciones."
        case .couldNotDetermine:
            "macOS no ha podido confirmar el estado actual de la cuenta."
        case .failed(let errorMessage):
            errorMessage
        }
    }

    var systemImage: String {
        switch self {
        case .checking:
            "icloud"
        case .available:
            "checkmark.icloud"
        case .restricted, .noAccount, .failed:
            "exclamationmark.icloud"
        case .temporarilyUnavailable, .couldNotDetermine:
            "icloud.slash"
        }
    }

    var tint: Color {
        switch self {
        case .checking, .couldNotDetermine:
            .secondary
        case .available:
            .green
        case .temporarilyUnavailable:
            .orange
        case .restricted, .noAccount, .failed:
            .red
        }
    }
}

private struct ICloudSyncEvent: Identifiable, Equatable {
    let id: UUID
    let typeLabel: String
    let statusLabel: String
    let startDate: Date
    let endDate: Date?
    let succeeded: Bool
    let errorMessage: String?

    init(event: NSPersistentCloudKitContainer.Event) {
        self.id = event.identifier
        self.typeLabel = Self.label(for: event.type)
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.succeeded = event.succeeded
        self.errorMessage = event.error?.localizedDescription

        if event.endDate == nil {
            self.statusLabel = "En curso"
        } else if event.succeeded {
            self.statusLabel = "Completado"
        } else {
            self.statusLabel = "Error"
        }
    }

    var summary: String {
        "\(typeLabel): \(statusLabel)"
    }

    var systemImage: String {
        if endDate == nil {
            return "arrow.triangle.2.circlepath.icloud"
        }

        return succeeded ? "checkmark.icloud" : "exclamationmark.icloud"
    }

    var tint: Color {
        if endDate == nil {
            return .blue
        }

        return succeeded ? .green : .red
    }

    var dateRangeLabel: String {
        if let endDate {
            return "\(startDate.formatted(date: .abbreviated, time: .standard)) - \(endDate.formatted(date: .omitted, time: .standard))"
        }

        return startDate.formatted(date: .abbreviated, time: .standard)
    }

    private static func label(for type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup:
            "Preparación"
        case .import:
            "Importación"
        case .export:
            "Exportación"
        @unknown default:
            "Sincronización"
        }
    }
}
#endif
