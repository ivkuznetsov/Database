//
//  Database.swift
//

import Foundation
import CoreData
import CommonUtils
import os.log

public class Database {
    
    private class WeakContext {
        weak var context: NSManagedObjectContext?
        
        init(_ context: NSManagedObjectContext) {
            self.context = context
        }
    }
    
    private let serialQueue = DispatchQueue(label: "database.serialqueue")
    private let storeCoordinator: NSPersistentStoreCoordinator
    private let storeDescriptions: [StoreDescription]
    
    public let viewContext: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    public let writerContext: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    @RWAtomic private var privateContextsForMerge: [WeakContext] = []
    
    public init(storeDescriptions: [StoreDescription] = [StoreDescription.userDataStore],
                modelBundle: Bundle = Bundle.main) {
        
        let objectModel = NSManagedObjectModel.mergedModel(from: [modelBundle])!
        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
        self.storeDescriptions = storeDescriptions
        
        writerContext.persistentStoreCoordinator = storeCoordinator
        writerContext.mergePolicy = NSOverwriteMergePolicy
        
        viewContext.persistentStoreCoordinator = storeCoordinator
        viewContext.mergePolicy = NSRollbackMergePolicy
        
        for identifier in storeCoordinator.managedObjectModel.configurations {
            addStore(configuration: identifier, coordinator: storeCoordinator)
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextChanged(notification:)),
                                               name: Notification.Name.NSManagedObjectContextDidSave,
                                               object: nil)
    }
    
    @discardableResult
    func onEditQueueSync<T>(_ closure: ()->T) -> T {
        serialQueue.sync(execute: closure)
    }
    
    func onEditQueue(_ closure: @escaping ()->()) {
        serialQueue.async(execute: closure)
    }
    
    public func idFor(uriRepresentation: URL) -> NSManagedObjectID? {
        storeCoordinator.managedObjectID(forURIRepresentation: uriRepresentation)
    }
    
    public func createPrivateContext(mergeChanges: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = writerContext
        if mergeChanges {
            _privateContextsForMerge.mutate { $0.append(WeakContext(context)) }
        }
        return context
    }
    
    public func createPrivateContext() -> NSManagedObjectContext {
        createPrivateContext(mergeChanges: false)
    }
    
    func log(_ message: String) {
        os_log("%@", message)
    }
    
    @objc func contextChanged(notification: Notification) {
        if let context = notification.object as? NSManagedObjectContext, context == writerContext {
            
            var classes = Set<String>()
            
            let extract: (String)->Set<URL> = { key in
                let set = notification.userInfo?[key] as? Set<NSManagedObject> ?? Set()
                
                return Set(set.map { object in
                    classes.insert(String(describing: type(of: object)))
                    return object.objectID.uriRepresentation()
                })
            }
            
            let appNotification = AppNotification(created: extract("inserted"),
                                                  updated: extract("updated"),
                                                  deleted: extract("deleted"))
            
            DispatchQueue.main.async { [weak self] in
                self?.viewContext.mergeChanges(fromContextDidSave: notification)
                
                NotificationManager.shared.postNotification(names: Array(classes), notification: appNotification)
            }
            
            _privateContextsForMerge.mutate {
                $0.removeAll {
                    if let mergeContext = $0.context {
                        if context.savingChild != mergeContext {
                            mergeContext.perform {
                                mergeContext.mergeChanges(fromContextDidSave: notification)
                            }
                        }
                        return false
                    } else {
                        return true
                    }
                }
            }
        }
    }
    
    private func storeDescriptionFor(configuration: String) -> StoreDescription {
        storeDescriptions.first { $0.configuration == configuration }!
    }
    
    private func addStore(configuration: String, coordinator: NSPersistentStoreCoordinator) {
        let description = storeDescriptionFor(configuration: configuration)
        
        var options: [String : Any] = [NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true]
        
        if description.readOnly {
            options[NSReadOnlyPersistentStoreOption] = true
        }
        description.options.forEach { options[$0.key] = $0.value }
        
        do {
            try coordinator.addPersistentStore(ofType: description.storeType, configurationName: configuration, at: description.url, options: options)
            
            os_log("Store has been added: %@", description.url.path)
        } catch {
            os_log("Error while creating persistent store: %@ for configuration %@", error.localizedDescription, configuration)
            
            if description.deleteOnError {
                description.removeStoreFiles()
                addStore(configuration: configuration, coordinator: coordinator)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
