//
//  ObjectId.swift
//

import CoreData

public protocol WithObjectId {}

public extension WithObjectId where Self: NSManagedObject {
    
    var getObjectId: ObjectId<Self> { ObjectId(self) }
}

extension NSManagedObject: WithObjectId { }

public struct ObjectId<T: NSManagedObject>: Hashable, Sendable {
    public let objectId: NSManagedObjectID
    
    public init(_ object: T) {
        objectId = object.permanentObjectID
    }
    
    init(_ objectId: NSManagedObjectID) {
        self.objectId = objectId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
    }
    
    @MainActor public func object(_ database: Database) -> T? {
        object(database.viewContext)
    }
    
    public func object(_ ctx: NSManagedObjectContext) -> T? {
        T.find(objectId: objectId, ctx: ctx)
    }
}

public extension Sequence {
    
    @MainActor func objects<U: NSManagedObject>(_ database: Database) -> [U] where Element == ObjectId<U> {
        objects(database.viewContext)
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

