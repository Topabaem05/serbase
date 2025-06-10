//
//  serbaseApp.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI

@main
struct serbaseApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
