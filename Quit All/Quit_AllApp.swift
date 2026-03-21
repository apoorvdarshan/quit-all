//
//  Quit_AllApp.swift
//  Quit All
//
//  Created by Apoorv Darshan on 22/03/26.
//

import SwiftUI
import CoreData

@main
struct Quit_AllApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
