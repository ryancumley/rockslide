//
//  Basic_ExampleApp.swift
//  Shared
//
//  Created by Ryan Cumley on 11/18/21.
//

import SwiftUI
import rockslide

@main
struct Basic_ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            RandomHalloweenCostumeSpawner() ~>> StateManager() ~>> ContentView.self
        }
    }
}
