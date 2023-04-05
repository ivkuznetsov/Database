//
//  StoreDescription.swift
//

import Foundation
import CoreData
import CommonUtils

public extension NSPersistentStoreDescription {
    
    enum Configuration {
        case local(name: String)
        case cloud(name: String, identifier: String)
        
        var name: String {
            switch self {
            case .local(let name), .cloud(let name, _): return name
            }
        }
    }
    
    static func dataStore(_ configuration: Configuration? = nil,
                          setup: (NSPersistentStoreDescription)->() = { _ in }) -> NSPersistentStoreDescription {
        
        description(configuration,
                    url: URL(fileURLWithPath: FileManager.applicationSupportDirectory + "/" + databaseFileName + (configuration?.name ?? "")),
                    setup: setup)
    }
    
    static func transientStore(_ configuration: Configuration? = nil,
                               setup: (NSPersistentStoreDescription)->() = { _ in }) -> NSPersistentStoreDescription {
        
        let store = description(configuration, url: URL(string: "memory://")!, setup: setup)
        store.type = NSInMemoryStoreType
        return store
    }
    
    private static func description(_ configuration: Configuration?,
                                    url: URL,
                                    setup: (NSPersistentStoreDescription)->()) -> NSPersistentStoreDescription {
        
        let store = NSPersistentStoreDescription(url: url)
        store.configuration = configuration?.name ?? "PF_DEFAULT_CONFIGURATION_NAME"
        
        if case .cloud(_, let identifier) = configuration {
            store.cloudKitContainerOptions = .init(containerIdentifier: identifier)
        }
        store.shouldMigrateStoreAutomatically = true
        store.shouldMigrateStoreAutomatically = true
        
        setup(store)
        
        return store
    }
    
    private static var databaseFileName: String {
        ProcessInfo.processInfo.processName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) + ".sqlite"
    }
    
    final func copyStoreFileFrom(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path), let currentUrl = self.url {
            try FileManager.default.copyItem(at: url, to: currentUrl)
        }
    }
    
    final func removeStoreFiles() {
        guard let url = url else { return }
        
        let databaseDirectory = url.deletingLastPathComponent()
        
        if let filePathes = try? FileManager.default.contentsOfDirectory(atPath: databaseDirectory.path) {
            for fileName in filePathes {
                if fileName.contains(Swift.type(of: self).databaseFileName) {
                    try? FileManager.default.removeItem(at: databaseDirectory.appendingPathComponent(fileName))
                }
            }
        }
    }
}
