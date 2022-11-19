//
//  Database+Additions.swift
//

import Foundation
import CoreData
import CommonUtils

public extension Database {
    
    func fetchSome<T>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> T) -> Work<T> {
         AsyncWork { work in
            self.fetch { ctx in
                do {
                    work.resolve(try closure(ctx))
                } catch {
                    work.reject(error)
                }
            }
         }
    }
    
    func fetchSome<U: NSManagedObject, T>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> T) -> Work<T> {
        
        fetchSome { ctx in
            if let object = objectId.object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetchOp<T>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> Work<T>?) -> Work<T> {
        fetchSome(closure).chainOrCancel(progress: .weight(0.9)) { $0 }
    }
    
    func fetchOp(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> ()) -> VoidWork {
        fetchSome(closure)
    }
    
    func fetchOp<U: NSManagedObject, T>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> Work<T>?) -> Work<T> {
        
        fetchOp { ctx in
            if let object = objectId.object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetchOp<U: NSManagedObject, R: NSManagedObject, T>(_ objectId1: ObjectId<U>,
                                                            _ objectId2: ObjectId<R>,
                                                            closure: @escaping (U, R, _ ctx: NSManagedObjectContext) throws -> Work<T>?) -> Work<T> {
        fetchOp { ctx in
            if let object1 = objectId1.object(ctx), let object2 = objectId2.object(ctx) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetchOp<U: NSManagedObject>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> ()) -> VoidWork {
        
        fetchOp { ctx in
            if let object = objectId.object(ctx) {
                try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetchOp<U: NSManagedObject, T>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> Work<T>?) -> Work<T> {
        fetchOp(object.getObjectId, closure: closure)
    }
    
    func fetchOp<U: NSManagedObject>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws ->()) -> VoidWork {
        fetchOp(object.getObjectId, closure: closure)
    }
    
    func editOp<T>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws ->T) -> Work<T> {
        AsyncWork { work in
            self.edit { ctx in
                do {
                    let result = try closure(ctx)
                    ctx.saveAll()
                    work.resolve(result)
                } catch {
                    work.reject(error)
                }
            }
        }
    }
    
    func editOp<U: NSManagedObject>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws ->()) -> VoidWork {
        
        editOp { ctx in
            if let object = objectId.object(ctx) {
                try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func editOp<U: NSManagedObject, T>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws ->Work<T>?) -> Work<T> {
        
        editOp { ctx in
            if let object = objectId.object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }.chainOrCancel(progress: .weight(0.9)) { work -> Work<T>? in work }
    }
    
    func editOp<U: NSManagedObject, T>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws ->Work<T>?) -> Work<T> {
        
        editOp(object.getObjectId, closure: closure)
    }
    
    func editOp<U: NSManagedObject>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws ->()) -> VoidWork {
        
        editOp(object.getObjectId, closure: closure)
    }
}
