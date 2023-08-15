//
//  Database.swift
//

import Foundation
import CoreData
import os.log
import Combine
import CloudKit

public final class Database {
    
    private actor TaskSync {
        
        private var task: Task<Any, Error>?
        
        public func run<Success>(_ block: @Sendable @escaping () async throws -> Success) async throws -> Success {
            task = Task { [task] in
                _ = await task?.result
                return try await block() as Any
            }
            return try await task!.value as! Success
        }
    }
    
    private let editSync = TaskSync()
    private let historyQueue = DispatchQueue(label: "database.history")
    public let container: NSPersistentCloudKitContainer
    
    public var viewContext: NSManagedObjectContext { container.viewContext }
    public let writerContext: NSManagedObjectContext
    
    public init(storeDescriptions: [NSPersistentStoreDescription] = [.dataStore()],
                modelBundle: Bundle = Bundle.main) {
        
        let model = NSManagedObjectModel.mergedModel(from: [modelBundle])!
        container = NSPersistentCloudKitContainer(name: "Database", managedObjectModel: model)
        
        writerContext = container.newBackgroundContext()
        writerContext.automaticallyMergesChangesFromParent = true
        writerContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        viewContext.mergePolicy = NSRollbackMergePolicy
        viewContext.name = "view"
        viewContext.automaticallyMergesChangesFromParent = true
        container.persistentStoreDescriptions = storeDescriptions
        
        if storeDescriptions.contains(where: { $0.options[NSPersistentHistoryTrackingKey] as? NSNumber == true }) {
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).sink { [weak self] in
                self?.didRemoteChange(notification: $0)
            }.retained(by: self)
        } else {
            NotificationCenter.default.publisher(for: NSManagedObjectContext.didMergeChangesObjectIDsNotification).sink { [weak self] in
                self?.didMerge($0)
            }.retained(by: self)
        }
        
        setup()
    }
    
    private func historyToken(with storeUUID: String) -> NSPersistentHistoryToken? {
        if let data = UserDefaults.standard.data(forKey: "HistoryToken" + storeUUID) {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
        }
        return nil
    }
    
    private func updateHistoryToken(with storeUUID: String, newToken: NSPersistentHistoryToken) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: "HistoryToken" + storeUUID)
    }
    
    public struct Change {
        public let classes: Set<String>
        public let inserted: Set<NSManagedObjectID>
        public let updated: Set<NSManagedObjectID>
        public let deleted: Set<NSManagedObjectID>
    }
    
    public let objectsDidChange = PassthroughSubject<Change, Never>()
    public let sharePublisher = PassthroughSubject<Void, Never>()
    
    private func didRemoteChange(notification: Notification) {
        guard let storeUUID = notification.userInfo?[NSStoreUUIDKey] as? String,
              let privateStore = privateStore,
              let sharedStore = sharedStore,
              privateStore.identifier == storeUUID ||
              sharedStore.identifier == storeUUID else {
            print("\(#function): Ignore a store remote Change notification because of no valid storeUUID.")
            return
        }
        
        Task {
            try await fetch { ctx in
                try self.historyQueue.sync {
                    let lastHistoryToken = self.historyToken(with: storeUUID)
                    let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)
                    request.fetchRequest = NSPersistentHistoryTransaction.fetchRequest

                    if privateStore.identifier == storeUUID {
                        request.affectedStores = [privateStore]
                    } else if sharedStore.identifier == storeUUID {
                        request.affectedStores = [sharedStore]
                    }
                    
                    guard let result = try ctx.execute(request) as? NSPersistentHistoryResult,
                          let transactions = result.result as? [NSPersistentHistoryTransaction] else {
                        return
                    }
                    
                    if transactions.isEmpty { // when transaction is empty it looks like CKShare is changed
                        DispatchQueue.onMain {
                            self.sharePublisher.send()
                        }
                    } else {
                        if let newToken = transactions.last?.token {
                            self.updateHistoryToken(with: storeUUID, newToken: newToken)
                        }
                        
                        var classes = Set<String>()
                        var inserted = Set<NSManagedObjectID>()
                        var updated = Set<NSManagedObjectID>()
                        var deleted = Set<NSManagedObjectID>()
                        
                        transactions.forEach {
                            var others = Set<NSPersistentHistoryChange>()
                            $0.changes?.forEach { change in
                                if case .delete = change.changeType {
                                    guard let className = change.changedObjectID.entity.name else { return }
                                    
                                    classes.insert(className)
                                    deleted.insert(change.changedObjectID)
                                } else {
                                    others.insert(change)
                                }
                            }
                            
                            others.forEach { change in
                                guard !deleted.contains(change.changedObjectID),
                                        let className = change.changedObjectID.entity.name else { return }
                                classes.insert(className)
                                
                                switch change.changeType {
                                case .insert:
                                    inserted.insert(change.changedObjectID)
                                case .update:
                                    updated.insert(change.changedObjectID)
                                default: break
                                }
                            }
                        }
                        
                        if classes.count > 0 {
                            DispatchQueue.onMain {
                                self.objectsDidChange.send(Change(classes: classes,
                                                                  inserted: inserted,
                                                                  updated: updated,
                                                                  deleted: deleted))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func didMerge(_ notification: Notification) {
        if let context = notification.object as? NSManagedObjectContext,
            context == viewContext,
            let userInfo = notification.userInfo {
            
            var classes = Set<String>()
            
            let extract: (String)->Set<NSManagedObjectID> = { key in
                let set = userInfo[key] as? Set<NSManagedObjectID> ?? Set()
                
                return Set(set.compactMap { objectId in
                    guard let className = objectId.entity.name else { return nil }
                    
                    if className.hasPrefix("NSCK") { return nil } //skip system items
                    
                    classes.insert(className)
                    return objectId
                })
            }
            
            let inserted = extract("inserted_objectIDs")
            let updated = extract("updated_objectIDs")
            let deleted = extract("deleted_objectIDs")
            
            if classes.count > 0 {
                objectsDidChange.send(Change(classes: classes,
                                             inserted: inserted,
                                             updated: updated,
                                             deleted: deleted))
            }
        }
    }
    
    private func setup() {
        container.loadPersistentStores { description, error in
            if let error = error {
                os_log("Error while creating persistent store: %@ for configuration %@", error.localizedDescription, description.configuration!)
                
                if (error as NSError).code == 134110 { //couldn't migrate in-place
                    description.removeStoreFiles()
                    self.setup()
                }
            } else {
                os_log("Store has been added: %@", description.url!.path)
            }
        }
    }
    
    public var privateStore: NSPersistentStore? {
        let description = container.persistentStoreDescriptions.first {
            if let options = $0.cloudKitContainerOptions {
                return options.databaseScope == .private
            }
            return true
        }
        
        if let url = description?.url {
            return container.persistentStoreCoordinator.persistentStore(for: url)
        }
        return nil
    }
    
    public var sharedStore: NSPersistentStore? {
        if let url = container.persistentStoreDescriptions.first(where: {
            $0.cloudKitContainerOptions?.databaseScope == .shared
        })?.url {
            return container.persistentStoreCoordinator.persistentStore(for: url)
        }
        return nil
    }
    
    @discardableResult
    func onEdit<T>(_ closure: @escaping () async throws ->T) async throws -> T {
        try await editSync.run {
            try await closure()
        }
    }
    
    public func idFor(uriRepresentation: URL) -> NSManagedObjectID? {
        container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: uriRepresentation)
    }
    
    public func createPrivateContext(mergeChanges: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.transactionAuthor = "app"
        context.automaticallyMergesChangesFromParent = mergeChanges
        context.parent = writerContext
        return context
    }
    
    public func createPrivateContext() -> NSManagedObjectContext {
        createPrivateContext(mergeChanges: false)
    }
}

extension DispatchQueue {
    
    static func onMain(_ closure: @escaping ()->()) {
        if Thread.isMainThread {
            closure()
        } else {
            main.async(execute: closure)
        }
    }
}
