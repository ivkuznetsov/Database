//
//  Database.swift
//

import Foundation
import CoreData
import CommonUtils
import os.log
import Combine

public final class Database {
    
    private let serialTask = SerialTasks()
    private let container: NSPersistentCloudKitContainer
    
    public var viewContext: NSManagedObjectContext { container.viewContext }
    public let writerContext: NSManagedObjectContext
    
    public init(storeDescriptions: [NSPersistentStoreDescription] = [.dataStore()],
                modelBundle: Bundle = Bundle.main) {
        
        let model = NSManagedObjectModel.mergedModel(from: [modelBundle])!
        container = NSPersistentCloudKitContainer(name: "Database", managedObjectModel: model)
        
        writerContext = container.newBackgroundContext()
        writerContext.automaticallyMergesChangesFromParent = true
        writerContext.mergePolicy = NSOverwriteMergePolicy
        
        viewContext.mergePolicy = NSRollbackMergePolicy
        viewContext.name = "view"
        viewContext.automaticallyMergesChangesFromParent = true
        container.persistentStoreDescriptions = storeDescriptions
        
        NotificationCenter.default.publisher(for: NSManagedObjectContext.didMergeChangesObjectIDsNotification).sink { [weak self] in
            self?.didMerge($0)
        }.retained(by: self)
        
        setup()
    }
    
    public struct Change {
        public let classes: Set<String>
        public let inserted: Set<NSManagedObjectID>
        public let updated: Set<NSManagedObjectID>
        public let deleted: Set<NSManagedObjectID>
    }
    
    private let objectsPublisher = PassthroughSubject<Change, Never>()
    public var objectsDidChange: AnyPublisher<Change, Never> { objectsPublisher.eraseToAnyPublisher() }
    
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
                objectsPublisher.send(Change(classes: classes,
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
    
    @discardableResult
    func onEdit<T>(_ closure: @escaping () async throws ->T) async throws -> T {
        try await serialTask.run {
            try await closure()
        }
    }
    
    public func idFor(uriRepresentation: URL) -> NSManagedObjectID? {
        container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: uriRepresentation)
    }
    
    public func createPrivateContext(mergeChanges: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.automaticallyMergesChangesFromParent = mergeChanges
        context.parent = writerContext
        return context
    }
    
    public func createPrivateContext() -> NSManagedObjectContext {
        createPrivateContext(mergeChanges: false)
    }
}
