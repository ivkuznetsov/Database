//
//  NSManagedObjectContext+DatabaseKit.swift
//  DatabaseKit
//
//  Created by Ilya Kuznetsov on 11/22/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData
import os.log

extension NSManagedObjectContext {
    
    public func create<T: NSManagedObject>(_ type: T.Type) -> T {
        NSEntityDescription.insertNewObject(forEntityName: String(describing: T.self), into: self) as! T
    }
    
    public func execute<T: NSManagedObject>(request: NSFetchRequest<T>) throws -> [T] {
        request.entity = NSEntityDescription.entity(forEntityName: String(describing: T.self), in: self)!
        return try fetch(request)
    }
    
    public func all<T: NSManagedObject>(_ type: T.Type) -> [T] {
        let request = NSFetchRequest<T>()
        
        do {
            return try execute(request: request)
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return []
    }
    
    public func allSorted<T: NSManagedObject>(_ type: T.Type) -> [T] {
        allSortedBy(key: \T.objectID.description, type: type)
    }
    
    public func allSortedBy<T: NSManagedObject, U>(key: KeyPath<T, U>,
                                                   ascending: Bool = true,
                                                   type: T.Type) -> [T] where U: Comparable {
        let request = NSFetchRequest<T>()
        request.sortDescriptors = [NSSortDescriptor(keyPath: key, ascending: ascending)]
        
        do {
            return try execute(request: request)
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return []
    }
    
    public func find<T: NSManagedObject, U: CVarArg>(_ type: T.Type, _ keyPath: KeyPath<T, U>, _ value: U) -> [T] {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return find(type, predicate: predicate)
    }
    
    public func find<T: NSManagedObject, U: CVarArg>(_ type: T.Type, _ keyPath: ReferenceWritableKeyPath<T, U?>, _ value: U) -> [T] {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return find(type, predicate: predicate)
    }
    
    public func find<T: NSManagedObject>(_ type: T.Type, _ format: String, _ args: CVarArg...) -> [T] {
        let predicate = NSPredicate(format: format, arguments: getVaList(args))
        return find(type, predicate: predicate)
    }
    
    public func find<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate) -> [T] {
        let request = NSFetchRequest<T>()
        request.predicate = predicate
        
        do {
            return try execute(request: request)
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return []
    }
    
    public func findFirst<T: NSManagedObject, U: CVarArg>(_ type: T.Type, _ keyPath: KeyPath<T, U>, _ value: U) -> T? {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return findFirst(type, predicate: predicate)
    }
    
    public func findFirst<T: NSManagedObject, U: CVarArg>(_ type: T.Type, _ keyPath: ReferenceWritableKeyPath<T, U?>, _ value: U) -> T? {
        let predicate = NSPredicate(format: (value as? String == nil) ? "\(keyPath._kvcKeyPathString!) == \(value)" : "\(keyPath._kvcKeyPathString!) == \"\(value)\"")
        return findFirst(type, predicate: predicate)
    }
    
    public func findFirst<T: NSManagedObject>(_ type: T.Type, _ format: String, _ args: CVarArg...) -> T? {
        let predicate = NSPredicate(format: format, arguments: getVaList(args))
        return findFirst(type, predicate: predicate)
    }
    
    public func findFirst<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate) -> T? {
        let request = NSFetchRequest<T>()
        request.fetchLimit = 1
        request.predicate = predicate
        
        do {
            return try execute(request: request).first
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return nil
    }
    
    public func objectsWith<T: Sequence>(ids: T) -> [NSManagedObject] where T.Element: NSManagedObjectID {
        return ids.compactMap { return find(type: NSManagedObject.self, objectId: $0) }
    }
    
    public func objectsWith<T: Sequence, U: NSManagedObject>(ids: T, type: U.Type) -> [U] where T.Element: NSManagedObjectID {
        return ids.compactMap { return find(type: type, objectId: $0) }
    }
    
    public func find<T: NSManagedObject>(type: T.Type, objectId: NSManagedObjectID) -> T? {
        do {
            return try self.existingObject(with: objectId) as? T
        } catch {
            os_log("%@", error.localizedDescription)
        }
        return nil
    }
    
    public func get<T: Sequence, U: NSManagedObject>(_ ids: T) -> [U] where T.Element == ObjectId<U> {
        ids.compactMap { return get($0) }
    }
    
    public func get<T: NSManagedObject>(_ objectId: ObjectId<T>) -> T? {
        find(type: T.self, objectId: objectId.objectId)
    }
    
    private static var savingContextKey = "savingContext"
    
    var savingChild: NSManagedObjectContext? {
        get { objc_getAssociatedObject(self, &NSManagedObjectContext.savingContextKey) as? NSManagedObjectContext }
        set { objc_setAssociatedObject(self, &NSManagedObjectContext.savingContextKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    public func saveAll() {
        precondition(concurrencyType != .mainQueueConcurrencyType, "View context cannot be saved")
        
        if hasChanges {
            performAndWait {
                do {
                    try save()
                    
                    if let parent = parent, parent.hasChanges {
                        parent.performAndWait {
                            do {
                                parent.savingChild = self
                                try parent.save()
                                parent.savingChild = nil
                            } catch {
                                os_log("%@\n%@", error.localizedDescription, (error as NSError).userInfo)
                            }
                        }
                    }
                } catch {
                    os_log("%@\n%@", error.localizedDescription, (error as NSError).userInfo)
                }
            }
        }
    }
}
