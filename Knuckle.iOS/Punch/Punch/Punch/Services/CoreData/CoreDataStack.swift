//
//  CoreDataStack.swift
//  Punch
//
//  NSPersistentContainer setup for local storage
//

import Foundation
import CoreData
import os.log

final class CoreDataStack {
    static let shared = CoreDataStack()

    private let containerName = "Knuckle"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.knuckle", category: "coredata")
    private(set) var loadError: Error?

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: containerName)

        // Configure for App Groups to share with widget
        let storeDescription: NSPersistentStoreDescription
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.paulmignard.Knuckle2") {
            let storeURL = groupURL.appendingPathComponent("\(containerName).sqlite")
            storeDescription = NSPersistentStoreDescription(url: storeURL)
        } else {
            self.logger.error("CoreData: App Group container not available, falling back to default store location")
            storeDescription = NSPersistentStoreDescription()
        }
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        // Must stay readable when a geofence event relaunches the app while
        // the device is locked — anything stricter than this makes background
        // launches fail to load geofences and drop the event
        storeDescription.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)

        container.persistentStoreDescriptions = [storeDescription]

        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.knuckle", category: "coredata")
                    .error("CoreData: Failed to load persistent stores: \(error.localizedDescription)")
                self?.loadError = error
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }

    private init() {}

    // MARK: - Save

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            try? context.save()
        }
    }

    func save(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
