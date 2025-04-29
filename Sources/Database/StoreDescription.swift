//
//  StoreDescription.swift
//

import Foundation
import CoreData
import CloudKit

extension NSPersistentStoreDescription: @unchecked @retroactive Sendable { }

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
    
    @available(*, deprecated, message: "Use localData(), data file has been renamed")
    static func dataStore(_ configuration: Configuration? = nil,
                          setup: (NSPersistentStoreDescription)->() = { _ in }) -> NSPersistentStoreDescription {
        
        description(configuration,
                    url: URL(fileURLWithPath: applicationSupportDirectory + "/" + databaseFileName + (configuration?.name ?? "")),
                    setup: setup)
    }
    
    static func localData(_ configuration: Configuration? = nil,
                          setup: (NSPersistentStoreDescription)->() = { _ in }) -> NSPersistentStoreDescription {
        
        description(configuration,
                    url: URL(fileURLWithPath: applicationSupportDirectory + "/" + (configuration?.name ?? "") + databaseFileName),
                    setup: setup)
    }
    
    static func cloudWithShare(_ name: String,
                               identifier: String,
                               setup: (_ cloud: NSPersistentStoreDescription,
                                       _ share: NSPersistentStoreDescription)->() = { _, _ in }) -> [NSPersistentStoreDescription] {
        let privatePath = applicationSupportDirectory + "/" + name + databaseFileName
        let sharedPath = applicationSupportDirectory + "/shared" + name + databaseFileName
        
        let privateDescription = self.description(.cloud(name: name, identifier: identifier), url: URL(fileURLWithPath: privatePath), setup: { _ in })
        
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        let sharedDescription = privateDescription.copy() as! NSPersistentStoreDescription
        sharedDescription.url = URL(fileURLWithPath: sharedPath)
        
        setup(privateDescription, sharedDescription)
        
        let sharedStoreOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
        sharedStoreOptions.databaseScope = .shared
        sharedDescription.cloudKitContainerOptions = sharedStoreOptions
        
        return [privateDescription, sharedDescription]
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
    
    static var applicationSupportDirectory: String {
        let dir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0] + "/" + Bundle.main.bundleIdentifier!
        
        if !FileManager.default.fileExists(atPath: dir) {
            try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
}
