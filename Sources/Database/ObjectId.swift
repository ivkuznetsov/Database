//
//  ObjectId.swift
//

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
    
    public func object() -> T? {
        object(Database.global.viewContext)
    }
    
    public func object(_ ctx: NSManagedObjectContext) -> T? {
        T.find(objectId: objectId, ctx: ctx)
    }
}

public extension Sequence {
    
    func objects<U: NSManagedObject>() -> [U] where Element == ObjectId<U> {
        objects(Database.global.viewContext)
    }
    
    func objects<U: NSManagedObject>(_ ctx: NSManagedObjectContext) -> [U] where Element == ObjectId<U> {
        compactMap { $0.object(ctx) }
    }
    
    func uri<U: NSManagedObject>() -> [URL] where Element == ObjectId<U> {
        map { $0.objectId.uriRepresentation() }
    }
}

public extension Sequence where Element: NSManagedObject {
    
    var ids: [ObjectId<Element>] { map { $0.getObjectId } }
}

