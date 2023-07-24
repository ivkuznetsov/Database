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
    
    var async: AsyncValue<Self> { AsyncValue(value: self) }
}

@dynamicMemberLookup
public struct AsyncValue<Value: NSManagedObject> {
    fileprivate let value: Value

    public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> () async throws -> T {
        { try await value.onMoc { value[keyPath: keyPath] } }
    }
}

extension NSManagedObject: ValueOnMoc {}

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
    
    func edit<R>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await onEdit {
            let context = self.createPrivateContext()
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
    
    func edit<R>(_ closure: @escaping (_ ctx: NSManagedObjectContext) -> R) async -> R {
        try! await onEdit {
            let context = self.createPrivateContext()
            if #available(iOS 15, macOS 12, *) {
                return await context.perform {
                    let result = closure(context)
                    context.saveAll()
                    return result
                }
            } else {
                return await withCheckedContinuation { continuation in
                    context.perform {
                        let result = closure(context)
                        context.saveAll()
                        continuation.resume(with: .success(result))
                    }
                }
            }
        }
    }
    
    func edit<T, R>(_ objectId: ObjectId<T>, _ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit { ctx in
            if let object = objectId.object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func edit<T: NSManagedObject, R>(_ object: T, _ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit(object.getObjectId, closure)
    }
    
    func edit<T: NSManagedObject, R>(_ objects: [T], _ closure: @escaping ([T], _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        let ids = objects.ids
        return try await edit {
            try closure(ids.objects($0), $0)
        }
    }
    
    func edit<T1, T2, R>(_ objectId1: ObjectId<T1>, _ objectId2: ObjectId<T2>, _ closure: @escaping (T1, T2, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit { ctx in
            if let object1 = objectId1.object(ctx), let object2 = objectId2.object(ctx) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func edit<T1: NSManagedObject, T2: NSManagedObject, R>(_ object1: T1, _ object2: T2, _ closure: @escaping (T1, T2, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit(object1.getObjectId, object2.getObjectId, closure)
    }
    
    func fetch<R>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        let context = createPrivateContext()
        
        if #available(iOS 15, macOS 12, *) {
            return try await context.perform {
                try closure(context)
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
    
    func fetch<R>(_ closure: @escaping (_ ctx: NSManagedObjectContext) -> R) async -> R {
        let context = createPrivateContext()
        
        if #available(iOS 15, macOS 12, *) {
            return await context.perform {
                closure(context)
            }
        } else {
            return await withCheckedContinuation { continuation in
                context.perform {
                    let result = closure(context)
                    context.saveAll()
                    continuation.resume(with: .success(result))
                }
            }
        }
    }
    
    func fetch<T, R>(_ objectId: ObjectId<T>, _ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch { ctx in
            if let object = objectId.object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetch<T: NSManagedObject, R>(_ object: T, _ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch(object.getObjectId, closure)
    }
    
    func fetch<T1, T2, R>(_ objectId1: ObjectId<T1>, _ objectId2: ObjectId<T2>, _ closure: @escaping (T1, T2, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch { ctx in
            if let object1 = objectId1.object(ctx), let object2 = objectId2.object(ctx) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetch<T1: NSManagedObject, T2: NSManagedObject, R>(_ object1: T1, _ object2: T2, _ closure: @escaping (T1, T2, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch(object1.getObjectId, object2.getObjectId, closure)
    }
}
