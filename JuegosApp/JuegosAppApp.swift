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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Game.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
            }

            SidebarCommands()
        }
#endif
    }
}
