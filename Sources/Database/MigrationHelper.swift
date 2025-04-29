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
                return
            }
                
            guard finalModel.version != currentModel.version else { return }
                
            try allModels(bundle: bundle).forEach {
                if $0.version > currentModel.version {
                    try performMigration(from: currentModel, to: $0, storeURL: url, storeType: description.type, bundle: bundle)
                    currentModel = $0
                }
            }
        }
    }
    
    func performMigration(from sourceModel: NSManagedObjectModel,
                          to destinationModel: NSManagedObjectModel,
                          storeURL: URL,
                          storeType: String,
                          bundle: Bundle) throws {
        
        let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        
        let destinationURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Temp-\(UUID().uuidString)")
        
        let mappingModel = try NSMappingModel(from: [bundle], forSourceModel: sourceModel, destinationModel: destinationModel) ??
        NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
        
        try migrationManager.migrateStore(from: storeURL,
                                          sourceType: storeType,
                                          with: mappingModel,
                                          toDestinationURL: destinationURL,
                                          destinationType: storeType)
        
        var storeURLs: [URL] = [storeURL]
        let fm = FileManager.default
        
        func add(_ resultExtension: String) {
            let url = storeURL.deletingPathExtension().appendingPathExtension(resultExtension)
            
            if fm.fileExists(atPath: url.path) {
                storeURLs.append(url)
            }
        }
        add("sqlite-wal")
        add("sqlite-shm")
        
        try storeURLs.forEach {
            try fm.copyItem(at: $0, to: $0.appendingPathExtension("backup"))
        }
        
        do {
            try storeURLs.forEach {
                try fm.removeItem(at: $0)
            }
            
            try FileManager.default.moveItem(at: destinationURL, to: storeURL)
        } catch {
            print("failed to copy database friles file: \(error.localizedDescription)")
            
            storeURLs.forEach {
                try? fm.moveItem(at: $0.appendingPathExtension("backup"), to: $0)
            }
        }
    }
}
