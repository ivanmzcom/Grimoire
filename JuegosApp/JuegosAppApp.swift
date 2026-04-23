//
//  JuegosAppApp.swift
//  JuegosApp
//
//  Created by Iván Moreno Zambudio on 23/4/26.
//

import SwiftUI
import SwiftData

@main
struct JuegosAppApp: App {
#if os(macOS)
    @StateObject private var iCloudSyncStatusModel = ICloudSyncStatusModel(
        containerIdentifier: AppCloudKitConfiguration.containerIdentifier
    )
#endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Game.self,
            GameList.self,
            GameListEntry.self,
            GameCopy.self,
            GamePlaythrough.self,
            GameTag.self,
            GameTagAssignment.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(AppCloudKitConfiguration.containerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        mainWindow

#if os(macOS)
        Settings {
            JuegosSettingsView()
                .environmentObject(iCloudSyncStatusModel)
                .modelContainer(sharedModelContainer)
        }
#endif
    }

    private var mainWindow: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .environmentObject(iCloudSyncStatusModel)
#endif
        }
#if os(macOS)
        .defaultSize(width: 1280, height: 820)
#endif
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuevo juego") {
                    NotificationCenter.default.post(name: .openNewGame, object: nil)
                }
                .keyboardShortcut("n")

                Button("Nueva lista") {
                    NotificationCenter.default.post(name: .openNewList, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            SidebarCommands()
        }
#endif
    }
}
