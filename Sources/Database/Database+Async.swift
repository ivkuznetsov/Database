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

public extension ObjectId {
    
    func edit<R>(_ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit(Database.global, closure)
    }
    
    func edit<R>(_ database: Database, _ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await database.edit { ctx in
            if let object = object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    func fetch<R>(_ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch(Database.global, closure)
    }
    
    func fetch<R>(_ database: Database, _ closure: @escaping (T, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await database.fetch { ctx in
            if let object = object(ctx) {
                return try closure(object, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
}

public extension ManagedObjectHelpers where Self: NSManagedObject {
    
    func edit<R>(_ closure: @escaping (Self, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit(Database.global, closure)
    }
    
    func edit<R>(_ database: Database, _ closure: @escaping (Self, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await getObjectId.edit(database, closure)
    }
    
    func fetch<R>(_ closure: @escaping (Self, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch(Database.global, closure)
    }
    
    func fetch<R>(_ database: Database, _ closure: @escaping (Self, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await getObjectId.fetch(database, closure)
    }
}

public extension Sequence where Element: NSManagedObject {
    
    func edit<R>(_ closure: @escaping ([Element], _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit(Database.global, closure)
    }
    
    func edit<R>(_ database: Database, _ closure: @escaping ([Element], _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        let ids = self.ids
        return try await database.edit {
            try closure(ids.objects($0), $0)
        }
    }
}

public extension Database {
    
    static func edit<R>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await Database.global.edit(closure)
    }
    
    static func edit<R>(_ database: Database, _ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await database.edit(closure)
    }
    
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
    
    static func fetch<R>(_ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await Database.global.fetch(closure)
    }
    
    static func fetch<R>(_ database: Database, _ closure: @escaping (_ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await database.fetch(closure)
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
}

public struct Couple<First: NSManagedObject, Second: NSManagedObject> {
    
    fileprivate let first: ObjectId<First>
    fileprivate let second: ObjectId<Second>
    
    public init(_ first: First, _ second: Second) {
        self.first = first.getObjectId
        self.second = second.getObjectId
    }
    
    public init(_ first: ObjectId<First>, _ second: ObjectId<Second>) {
        self.first = first
        self.second = second
    }
    
    public init(_ first: First, _ second: ObjectId<Second>) {
        self.first = first.getObjectId
        self.second = second
    }
    
    public init(_ first: ObjectId<First>, _ second: Second) {
        self.first = first
        self.second = second.getObjectId
    }
    
    public func edit<R>(_ closure: @escaping (First, Second, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await edit(Database.global, closure)
    }
    
    public func edit<R>(_ database: Database, _ closure: @escaping (First, Second, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await database.edit { ctx in
            if let object1 = first.object(ctx), let object2 = second.object(ctx) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
    
    public func fetch<R>(_ closure: @escaping (First, Second, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await fetch(Database.global, closure)
    }
    
    public func fetch<R>(_ database: Database, _ closure: @escaping (First, Second, _ ctx: NSManagedObjectContext) throws -> R) async throws -> R {
        try await database.fetch { ctx in
            if let object1 = first.object(ctx), let object2 = second.object(ctx) {
                return try closure(object1, object2, ctx)
            } else {
                throw RunError.cancelled
            }
        }
    }
}
