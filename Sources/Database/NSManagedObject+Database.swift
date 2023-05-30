//
//  NSManagedObject+DatabaseKit.swift
//

import Foundation
import CoreData
import os.log
import Combine

extension NSManagedObject: ManagedObjectHelpers { }

public protocol ManagedObjectHelpers { }

public struct Change<T: NSManagedObject> {
    public let inserted: Set<ObjectId<T>>
    public let updated: Set<ObjectId<T>>
    public let deleted: Set<ObjectId<T>>
}

public extension ManagedObjectHelpers where Self: NSManagedObject {
    
    static func didChange(_ database: Database) -> AnyPublisher<Change<Self>, Never> {
        objectsDidChange(database).map {
            Change(inserted: Set($0.inserted.map { ObjectId<Self>($0) }),
                   updated: Set($0.updated.map { ObjectId<Self>($0) }),
                   deleted: Set($0.deleted.map { ObjectId<Self>($0) }))
        }.eraseToAnyPublisher()
    }
    
    @MainActor static func all(_ database: Database) -> [Self] {
        all(database.viewContext)
    }
    
    static func all(_ ctx: NSManagedObjectContext) -> [Self] {
        let request = NSFetchRequest<Self>()
        
        do {
            return try ctx.execute(request: request)
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return []
    }
    
    @MainActor static func allSorted(_ database: Database) -> [Self] {
        allSorted(database.viewContext)
    }
    
    static func allSorted(_ ctx: NSManagedObjectContext) -> [Self] {
        allSortedBy(key: \Self.objectID.description, ctx: ctx)
    }
    
    @MainActor static func allSortedBy<U>(key: KeyPath<Self, U>,
                                          ascending: Bool = true,
                                          _ database: Database) -> [Self] where U: Comparable {
        allSortedBy(key: key, ascending: ascending, ctx: database.viewContext)
    }
    
    static func allSortedBy<U>(key: KeyPath<Self, U>,
                               ascending: Bool = true,
                               ctx: NSManagedObjectContext) -> [Self] where U: Comparable {
        let request = NSFetchRequest<Self>()
        request.sortDescriptors = [NSSortDescriptor(keyPath: key, ascending: ascending)]
        
        do {
            return try ctx.execute(request: request)
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return []
    }
    
    @MainActor static func find<U: CVarArg>(_ keyPath: KeyPath<Self, U>,
                                            _ value: U,
                                            _ database: Database) -> [Self] {
        find(keyPath, value, ctx: database.viewContext)
    }
    
    static func find<U: CVarArg>(_ keyPath: KeyPath<Self, U>,
                                 _ value: U,
                                 ctx: NSManagedObjectContext) -> [Self] {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return find(predicate: predicate, ctx: ctx)
    }
    
    @MainActor static func find<U: CVarArg>(_ keyPath: ReferenceWritableKeyPath<Self, U?>,
                                            _ value: U,
                                            _ database: Database) -> [Self] {
        find(keyPath, value, ctx: database.viewContext)
    }
    
    static func find<U: CVarArg>(_ keyPath: ReferenceWritableKeyPath<Self, U?>,
                                 _ value: U,
                                 ctx: NSManagedObjectContext) -> [Self] {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return find(predicate: predicate, ctx: ctx)
    }
    
    @MainActor static func find(_ database: Database,
                                _ format: String,
                                _ args: CVarArg...) -> [Self] {
        find(ctx: database.viewContext, format, args)
    }
    
    static func find(ctx: NSManagedObjectContext,
                     _ format: String,
                     _ args: CVarArg...) -> [Self] {
        let predicate = NSPredicate(format: format, arguments: getVaList(args))
        return find(predicate: predicate, ctx: ctx)
    }
    
    @MainActor static func find(predicate: NSPredicate, _ database: Database) -> [Self] {
        find(predicate: predicate, ctx: database.viewContext)
    }
        
    static func find(predicate: NSPredicate,
                     ctx: NSManagedObjectContext) -> [Self] {
        let request = NSFetchRequest<Self>()
        request.predicate = predicate
        
        do {
            return try ctx.execute(request: request)
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return []
    }
    
    @MainActor static func findFirst<U: CVarArg>(_ keyPath: KeyPath<Self, U>,
                                                 _ value: U,
                                                 _ database: Database) -> Self? {
        findFirst(keyPath, value, ctx: database.viewContext)
    }
    
    static func findFirst<U: CVarArg>(_ keyPath: KeyPath<Self, U>,
                                      _ value: U,
                                      ctx: NSManagedObjectContext) -> Self? {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return findFirst(predicate: predicate, ctx: ctx)
    }
    
    @MainActor static func findFirst<U: CVarArg>(_ keyPath: ReferenceWritableKeyPath<Self, U?>,
                                                 _ value: U,
                                                 _ database: Database) -> Self? {
        findFirst(keyPath, value, ctx: database.viewContext)
    }
        
    static func findFirst<U: CVarArg>(_ keyPath: ReferenceWritableKeyPath<Self, U?>,
                                      _ value: U,
                                      ctx: NSManagedObjectContext) -> Self? {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return findFirst(predicate: predicate, ctx: ctx)
    }
    
    @MainActor static func findFirst(_ database: Database,
                                     _ format: String,
                                     _ args: CVarArg...) -> Self? {
        findFirst(ctx: database.viewContext, format, args)
    }
    
    static func findFirst(ctx: NSManagedObjectContext,
                          _ format: String,
                          _ args: CVarArg...) -> Self? {
        let predicate = NSPredicate(format: format, arguments: getVaList(args))
        return findFirst(predicate: predicate, ctx: ctx)
    }
    
    @MainActor static func findFirst(predicate: NSPredicate, _ database: Database) -> Self? {
        findFirst(predicate: predicate, ctx: database.viewContext)
    }
    
    static func findFirst(predicate: NSPredicate,
                          ctx: NSManagedObjectContext) -> Self? {
        let request = NSFetchRequest<Self>()
        request.fetchLimit = 1
        request.predicate = predicate
        
        do {
            return try ctx.execute(request: request).first
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return nil
    }
    
    @MainActor static func find(objectId: NSManagedObjectID, _ database: Database) -> Self? {
        find(objectId: objectId, ctx: database.viewContext)
    }
    
    static func find(objectId: NSManagedObjectID,
                     ctx: NSManagedObjectContext) -> Self? {
        do {
            return try ctx.existingObject(with: objectId) as? Self
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return nil
    }
}

public extension NSManagedObject {
    
    func delete() {
        managedObjectContext?.delete(self)
    }
    
    var isObjectDeleted: Bool { managedObjectContext == nil || isDeleted }
    
    var permanentObjectID: NSManagedObjectID {
        var objectID = self.objectID
        
        if objectID.isTemporaryID {
            try? managedObjectContext?.obtainPermanentIDs(for: [self])
            objectID = self.objectID
        }
        return objectID
    }
    
    static func objectsDidChange(_ database: Database) -> AnyPublisher<Database.Change, Never> {
        [self].objectsDidChange(database)
    }
    
    static func objectsCountChanged(_ database: Database) -> AnyPublisher<Database.Change, Never> {
        [self].objectsCountChanged(database)
    }
}

public extension Collection where Element == NSManagedObject.Type {
    
    func objectsDidChange(_ database: Database) -> AnyPublisher<Database.Change, Never> {
        database.objectsDidChange.filter { change in
            contains(where: { item in
                if let name = item.entity().name, change.classes.contains(name) {
                    return true
                }
                return false
            })
        }.eraseToAnyPublisher()
    }
    
    func objectsCountChanged(_ database: Database) -> AnyPublisher<Database.Change, Never> {
        database.objectsDidChange.filter {
            $0.deleted.count > 0 || $0.inserted.count > 0
        }.eraseToAnyPublisher()
    }
}
