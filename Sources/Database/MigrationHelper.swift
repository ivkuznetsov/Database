//
//  MigrationHelper.swift
//  Database
//
//  Created by Kuznetsov, Ilia on 29.04.25.
//

import CoreData

extension NSManagedObjectModel {
    
    var version: Int {
        guard let string = versionIdentifiers.first as? String, let version = Int(string) else {
            fatalError("Models should have version identifiers: 1, 2, 3 etc.")
        }
        return version
    }
}

struct MigrationHelper {
    
    enum Error: Swift.Error {
        case unknownModel
        case migrationFailed(Swift.Error)
    }
    
    private func allModels(bundle: Bundle) throws -> [NSManagedObjectModel] {
        guard let resourceUrl = bundle.resourceURL else {
            return []
        }
        
        let fm = FileManager.default
        let modelsFolders = try fm.contentsOfDirectory(atPath: resourceUrl.path).filter { $0.hasSuffix(".momd") }
        
        guard let modelsFolder = modelsFolders.first, modelsFolders.count == 1 else {
            print("Should be exactly one model in the folder")
            return []
        }
        
        let modelsFolderURL = resourceUrl.appendingPathComponent(modelsFolder)
        let allModelsFiles = try fm.contentsOfDirectory(atPath: modelsFolderURL.path)
            .filter { $0.hasSuffix(".mom") }
            .map { modelsFolderURL.appendingPathComponent($0) }
        
        return allModelsFiles.compactMap { NSManagedObjectModel(contentsOf: $0) }.sorted { $0.version < $1.version }
    }
    
    func migrateIfNeeded(descriptions: [NSPersistentStoreDescription], bundle: Bundle, finalModel: NSManagedObjectModel) throws {
        try descriptions.forEach { description in
            guard let url = description.url, description.shouldInferMappingModelAutomatically == false else { return }
            
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .init(rawValue: description.type), at: url)
            
            guard var currentModel = NSManagedObjectModel.mergedModel(from: [bundle], forStoreMetadata: metadata) else {
                throw Error.unknownModel
            }
                
            guard finalModel.version != currentModel.version else { return }
                
            try allModels(bundle: bundle).forEach {
                if $0.version > currentModel.version {
                    do {
                        try performMigration(from: currentModel, to: $0, storeURL: url, storeType: description.type, bundle: bundle)
                    } catch {
                        throw Error.migrationFailed(error)
                    }
                    currentModel = $0
                }
            }
        }
    }
    
    func storeURLs(_ baseURL: URL, suffix: String = "") -> [URL] {
        var storeURLs: [URL] = []
        
        ["", "-wal", "-shm"].forEach {
            let url = baseURL.deletingLastPathComponent()
                .appendingPathComponent(baseURL.deletingPathExtension().lastPathComponent + suffix)
                .appendingPathExtension(baseURL.pathExtension + $0)
            storeURLs.append(url)
        }
        return storeURLs
    }
    
    func performMigration(from sourceModel: NSManagedObjectModel,
                          to destinationModel: NSManagedObjectModel,
                          storeURL: URL,
                          storeType: String,
                          bundle: Bundle) throws {
        
        let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        
        let fm = FileManager.default
        
        let storeURLs = storeURLs(storeURL)
        let destinationURLs = self.storeURLs(storeURL, suffix: "Temp")
        destinationURLs.forEach { try? fm.removeItem(at: $0) }
        
        let mappingModel = try NSMappingModel(from: [bundle], forSourceModel: sourceModel, destinationModel: destinationModel) ??
        NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
        
        try migrationManager.migrateStore(from: storeURL,
                                          sourceType: storeType,
                                          with: mappingModel,
                                          toDestinationURL: destinationURLs[0],
                                          destinationType: storeType)
        
        let backupURLs = self.storeURLs(storeURL, suffix: "Backup")
        backupURLs.forEach { try? fm.removeItem(at: $0) }
        
        try storeURLs.enumerated().forEach {
            if fm.fileExists(atPath: $1.path) {
                try fm.moveItem(at: $1, to: backupURLs[$0])
            }
        }
        
        do {
            storeURLs.forEach {
                try? fm.removeItem(at: $0)
            }
            try destinationURLs.enumerated().forEach {
                if fm.fileExists(atPath: $1.path) {
                    try fm.moveItem(at: $1, to: storeURLs[$0])
                }
            }
            
            backupURLs.forEach { try? fm.removeItem(at: $0) }
        } catch {
            print("failed to copy database friles file: \(error.localizedDescription)")
            
            backupURLs.enumerated().forEach {
                if fm.fileExists(atPath: $1.path) {
                    try? fm.moveItem(at: $1, to: storeURLs[$0])
                }
            }
        }
    }
}
