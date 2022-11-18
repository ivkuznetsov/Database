//
//  Database+Actions.swift
//

import Foundation
import CoreData

public protocol WithObjectId {}

public extension WithObjectId where Self: NSManagedObject {
    
    var getObjectId: ObjectId<Self> { ObjectId(self) }
}

extension NSManagedObject: WithObjectId { }

public struct ObjectId<T: NSManagedObject>: Hashable {
    public let objectId: NSManagedObjectID
    
    public init(_ object: T) {
        objectId = object.permanentObjectID
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
    }
    
    public func object(_ ctx: NSManagedObjectContext) -> T? {
        ctx.find(type: T.self, objectId: objectId)
    }
}

public extension Sequence {
    
    func objects<U: NSManagedObject>(_ ctx: NSManagedObjectContext) -> [U] where Element == ObjectId<U> {
        compactMap { $0.object(ctx) }
    }
}

public extension Sequence where Element: NSManagedObject {
    
    var ids: [ObjectId<Element>] { map { $0.getObjectId } }
}

public extension Database {
    
    @discardableResult
    func editSync<T>(_ closure: (_ ctx: NSManagedObjectContext)->T) -> T {
        return onEditQueueSync {
            let context = self.createPrivateContext()
            
            var result: T!
            context.performAndWait {
                result = closure(context)
                context.saveAll()
            }
            return result
        }
    }
    
    @discardableResult
    func editSyncWith<T, U: NSManagedObject>(_ objectId: ObjectId<U>, closure: (U, _ ctx: NSManagedObjectContext)->T?) -> T? {
        return editSync { ctx in
            if let object = ctx.get(objectId) {
                return closure(object, ctx)
            }
            return nil
        }
    }
    
    @discardableResult
    func editSyncWith<T, U: NSManagedObject, R: NSManagedObject>(_ objectId1: ObjectId<U>, _ objectId2: ObjectId<R>, closure: (U, R, _ ctx: NSManagedObjectContext)->T?) -> T? {
        return editSync { ctx in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                return closure(object1, object2, ctx)
            }
            return nil
        }
    }
    
    @discardableResult
    func editSyncWith<T, U: NSManagedObject>(_ object: U, closure: (U, _ ctx: NSManagedObjectContext)->T?) -> T? {
        editSyncWith(ObjectId(object), closure: closure)
    }
    
    @discardableResult
    func editSyncWith<T, U: NSManagedObject, R: NSManagedObject>(_ object1: U, _ object2: R, closure: (U, R, _ ctx: NSManagedObjectContext)->T?) -> T? {
        editSyncWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
    
    func edit(_ closure: @escaping (_ ctx: NSManagedObjectContext)->()) {
        onEditQueue {
            let context = self.createPrivateContext()
            context.performAndWait {
                closure(context)
                context.saveAll()
            }
        }
    }
    
    func editWith<U: NSManagedObject>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext)->()) {
        edit { ctx in
            if let object = ctx.get(objectId) {
                closure(object, ctx)
            }
        }
    }
    
    func editWith<U: NSManagedObject, R: NSManagedObject>(_ objectId1: ObjectId<U>, _ objectId2: ObjectId<R>, closure: @escaping (U, R, _ ctx: NSManagedObjectContext)->()) {
        edit { ctx in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                closure(object1, object2, ctx)
            }
        }
    }
    
    func editWith<U: NSManagedObject>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext)->()) {
        editWith(ObjectId(object), closure: closure)
    }
    
    func editWith<U: NSManagedObject, R: NSManagedObject>(_ object1: U, object2: R, closure: @escaping (U, R, _ ctx: NSManagedObjectContext)->()) {
        editWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
    
    @discardableResult
    func fetchSync<T>(_ closure: (_ ctx: NSManagedObjectContext)->T) -> T {
        let ctx = createPrivateContext()
        var result: T!
        ctx.performAndWait {
            result = closure(ctx)
        }
        return result
    }
    
    @discardableResult
    func fetchSyncWith<T, U: NSManagedObject>(_ objectId: ObjectId<U>, closure: (U, _ ctx: NSManagedObjectContext)->T?) -> T? {
        return fetchSync { ctx in
            if let object = ctx.get(objectId) {
                return closure(object, ctx)
            }
            return nil
        }
    }
    
    @discardableResult
    func fetchSyncWith<T, U: NSManagedObject, R: NSManagedObject>(_ objectId1: ObjectId<U>, _ objectId2: ObjectId<R>, closure: (U, R, _ ctx: NSManagedObjectContext)->T?) -> T? {
        return fetchSync { ctx in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                return closure(object1, object2, ctx)
            }
            return nil
        }
    }
    
    @discardableResult
    func fetchSyncWith<T, U: NSManagedObject>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext)->T?) -> T? {
        fetchSyncWith(ObjectId(object), closure: closure)
    }
    
    @discardableResult
    func fetchSyncWith<T, U: NSManagedObject, R: NSManagedObject>(_ object1: U, _ object2: R, closure: @escaping (U, R, _ ctx: NSManagedObjectContext)->T) -> T? {
        fetchSyncWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
    
    func fetch(_ closure: @escaping (_ ctx: NSManagedObjectContext)->()) {
        let ctx = createPrivateContext()
        ctx.perform {
            closure(ctx)
        }
    }
    
    func fetchWith<U: NSManagedObject>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext)->()) {
        fetch { ctx in
            if let object = ctx.get(objectId) {
                closure(object, ctx)
            }
        }
    }
    
    func fetchWith<U: NSManagedObject, R: NSManagedObject>(_ objectId1: ObjectId<U>, _ objectId2: ObjectId<R>, closure: @escaping (U, R, _ ctx: NSManagedObjectContext)->()) {
        fetch { ctx in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                closure(object1, object2, ctx)
            }
        }
    }
    
    func fetchWith<U: NSManagedObject>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext)->()) {
        fetchWith(ObjectId(object), closure: closure)
    }
    
    func fetchWith<U: NSManagedObject, R: NSManagedObject>(_ object1: U, _ object2: R, closure: @escaping (U, R, _ ctx: NSManagedObjectContext)->()) {
        fetchWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
    
    func editLazy(_ closure: @escaping (NSManagedObjectContext, _ save: @escaping (_ saved: (()->())?)->())->()) {
        onEditQueue {
            let context = self.createPrivateContext(mergeChanges: true)
            context.perform {
                closure(context, { saved in
                    self.onEditQueue {
                        context.saveAll()
                        DispatchQueue.main.async(execute: { saved?() })
                    }
                })
            }
        }
    }
    
    func editLazyWith<U: NSManagedObject>(_ objectId: ObjectId<U>, closure: @escaping (U, NSManagedObjectContext, _ save: @escaping (_ saved: (()->())?)->())->()) {
        editLazy { ctx, save in
            if let object = ctx.get(objectId) {
                closure(object, ctx, save)
            }
        }
    }
    
    func editLazyWith<U: NSManagedObject, R: NSManagedObject>(_ objectId1: ObjectId<U>, _ objectId2: ObjectId<R>, closure: @escaping (U, R, NSManagedObjectContext, _ save: @escaping (_ saved: (()->())?)->())->()) {
        editLazy { ctx, save in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                closure(object1, object2, ctx, save)
            }
        }
    }
    
    func editLazyWith<U: NSManagedObject>(_ object: U, closure: @escaping (U, NSManagedObjectContext, _ save: @escaping (_ saved: (()->())?)->())->()) {
        editLazyWith(ObjectId(object), closure: closure)
    }
    
    func editLazyWith<U: NSManagedObject, R: NSManagedObject>(_ object1: U, object2: R, closure: @escaping (U, R, NSManagedObjectContext, _ save: @escaping (_ saved: (()->())?)->())->()) {
        editLazyWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
}
