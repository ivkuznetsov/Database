//
//  Database+Actions.swift
//

import Foundation
import CoreData

public extension Database {
    
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
}
