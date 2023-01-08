//
//  Database+Async.swift
//  
//
//  Created by Ilya Kuznetsov on 06/01/2023.
//

import CoreData
import CommonUtils

public protocol ValueOnMoc { }

public extension ValueOnMoc where Self: NSManagedObject {
    
    func async<T>(_ keyPath: KeyPath<Self, T>) async throws -> T {
        try await onMoc { self[keyPath: keyPath] }
    }
}

public extension NSManagedObject {
    
    func onMoc<T>(_ block: @escaping ()->T) async throws -> T {
        if let ctx = managedObjectContext {
            if #available(iOS 15, macOS 12, *) {
                return await ctx.perform { block() }
            } else {
                return await withCheckedContinuation { continuation in
                    ctx.perform {
                        continuation.resume(with: .success(block()))
                    }
                }
            }
        }
        throw RunError.cancelled
    }
}

public extension Database {
    
    func edit<T>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await onEdit {
            let context = createPrivateContext()
            if #available(iOS 15, macOS 12, *) {
                return try await context.perform {
                    let result = try closure(context)
                    context.saveAll()
                    return result
                }
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    context.perform {
                        do {
                            let result = try closure(context)
                            context.saveAll()
                            continuation.resume(with: .success(result))
                        } catch {
                            continuation.resume(with: .failure(error))
                        }
                    }
                }
            }
        }
    }
    
    func editWith<U: NSManagedObject, T>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await edit { ctx in
            if let object = ctx.get(objectId) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func editWith<U: NSManagedObject, R: NSManagedObject, T>(_ objectId1: ObjectId<U>,
                                                             _ objectId2: ObjectId<R>,
                                                             closure: @escaping (U, R, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await edit { ctx in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func editWith<U: NSManagedObject, T>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws ->T) async throws -> T {
        try await editWith(ObjectId(object), closure: closure)
    }
    
    func editWith<U: NSManagedObject, R: NSManagedObject, T>(_ object1: U, object2: R, closure: @escaping (U, R, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await editWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
    
    func fetch<T>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        let context = createPrivateContext()
        
        if #available(iOS 15, macOS 12, *) {
            return try await context.perform {
                return try closure(context)
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    do {
                        let result = try closure(context)
                        context.saveAll()
                        continuation.resume(with: .success(result))
                    } catch {
                        continuation.resume(with: .failure(error))
                    }
                }
            }
        }
    }
    
    func fetchWith<U: NSManagedObject, T>(_ objectId: ObjectId<U>, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await fetch { ctx in
            if let object = ctx.get(objectId) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetchWith<U: NSManagedObject, R: NSManagedObject, T>(_ objectId1: ObjectId<U>,
                                                              _ objectId2: ObjectId<R>,
                                                              closure: @escaping (U, R, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await fetch { ctx in
            if let object1 = ctx.get(objectId1), let object2 = ctx.get(objectId2) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetchWith<U: NSManagedObject, T>(_ object: U, closure: @escaping (U, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await fetchWith(ObjectId(object), closure: closure)
    }
    
    func fetchWith<U: NSManagedObject, R: NSManagedObject, T>(_ object1: U,
                                                              _ object2: R,
                                                              closure: @escaping (U, R, _ ctx: NSManagedObjectContext) throws -> T) async throws -> T {
        try await fetchWith(ObjectId(object1), ObjectId(object2), closure: closure)
    }
}

