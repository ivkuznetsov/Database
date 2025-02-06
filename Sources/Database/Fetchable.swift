//
//  Fetchable.swift
//

import Foundation
import CoreData

public protocol Uploadable: Fetchable {
    
    var toSource: Source { get }
}

public protocol Fetchable {
    associatedtype Id
    associatedtype Source
    
    var uid: Id { get set }
    func update(_ source: Source)
    
    static func uid(from source: Source) -> Id
    static func isValid(uid: Id) -> Bool
    static func isValid(source: Source) -> Bool
}

public extension Fetchable {
    
    static func isValid(source: Source) -> Bool { true }
}

public extension Fetchable where Id == String? {
    
    static func isValid(uid: String?) -> Bool { uid != nil }
}

public extension Fetchable where Id == UUID? {
    
    static func isValid(uid: UUID?) -> Bool { uid != nil }
}

public extension Fetchable where Source == [String:Any], Id == String? {
    
    static func uid(from source: [String:Any]) -> String? {
        var uid = source["uid"] as? String ?? source["id"] as? String
        
        if uid == nil, let id = source["id"] as? Int64 {
            uid = "\(id)"
        }
        if uid == nil {
            print("ID is not found, throwed by class: \(String(describing: self))")
        }
        return uid
    }
}

public extension Fetchable where Source == [String:Any], Id == UUID? {
    
    static func uid(from source: [String:Any]) -> UUID? {
        if let uid = source["uid"] as? String ?? source["id"] as? String,
           let uuid = UUID(uuidString: uid) {
            return uuid
        }
        print("ID is not found, throwed by class: \(String(describing: self))")
        return nil
    }
}

public extension Fetchable {
    
    func parse<U>(_ dict: [String : Any], _ keys: [(dbKey: ReferenceWritableKeyPath<Self, U?>, serviceKey: String)], dateConverted: ((String)->(Date?))? = nil) {
        for key in keys {
            if let value = dict[key.serviceKey] {
                if let value = value as? U {
                    self[keyPath: key.dbKey] = value
                } else if let value = value as? String, let dbKey = key.dbKey as? ReferenceWritableKeyPath<Self, Date?> {
                    self[keyPath: dbKey] = dateConverted?(value)
                } else {
                    self[keyPath: key.dbKey] = nil
                }
            }
        }
    }
    
    func parse<U>(_ dict: [String : Any], _ keys: [(dbKey: ReferenceWritableKeyPath<Self, U>, serviceKey: String)]) {
        for key in keys {
            if let value = dict[key.serviceKey] {
                if let value = value as? U {
                    self[keyPath: key.dbKey] = value
                } else if let value = value as? String {
                    if let dbKey = key.dbKey as? ReferenceWritableKeyPath<Self, Float> {
                        self[keyPath: dbKey] = Float(value) ?? 0
                    } else if let dbKey = key.dbKey as? ReferenceWritableKeyPath<Self, Double> {
                        self[keyPath: dbKey] = Double(value) ?? 0
                    } else if let dbKey = key.dbKey as? ReferenceWritableKeyPath<Self, Bool> {
                        self[keyPath: dbKey] = value == "1" ? true : (value == "true" ? true : false)
                    }
                } else if let dbKey = key.dbKey as? ReferenceWritableKeyPath<Self, Float>, let value = value as? Double {
                    self[keyPath: dbKey] = Float(value)
                }
            }
        }
    }
}

public protocol CustomPredicate {
    
    var searchPredicate: NSPredicate { get }
}

public extension Fetchable where Self: NSManagedObject {
    
    static func parse(_ array: [Source]?, additional: ((Self, Source)->())? = nil, deleteOldItems: Bool = false, ctx: NSManagedObjectContext) -> [Self] {
        guard let array = array else { return [] }
        
        var resultSet = Set<NSManagedObjectID>()
        var result: [Self] = []
        
        var oldItems = Set<Self>()
        
        if deleteOldItems {
            oldItems = Set(Self.all(ctx))
        }
        
        for source in array {
            if let object = findAndUpdate(source, ctx: ctx),
               !resultSet.contains(object.objectID) {
                oldItems.remove(object)
                resultSet.insert(object.objectID)
                result.append(object)
                additional?(object, source)
            }
        }
        
        if deleteOldItems {
            oldItems.forEach { $0.delete() }
        }
        return result
    }
    
    static func findOrCreatePlaceholder(uid: Id, ctx: NSManagedObjectContext) -> Self {
        var object: Self
        
        if let found = findFirst(.with("uid", uid), ctx: ctx) {
            object = found
        } else {
            object = self.init(context: ctx)
            object.uid = uid
        }
        return object
    }
    
    static func findAndUpdate(_ source: Source?, ctx: NSManagedObjectContext) -> Self? {
        guard let source = source, isValid(source: source) else { return nil }
        
        let uid = uid(from: source)
        
        guard isValid(uid: uid) else {
            return nil
        }
        let object = findOrCreatePlaceholder(uid: uid, ctx: ctx)
        object.update(source)
        return object
    }
}

public extension Fetchable where Self: NSManagedObject, Source == [String:Any] {
    
    func parse<T: Fetchable & NSManagedObject>(_ dict: [String:Any], _ dbKey: ReferenceWritableKeyPath<Self, T?>, _ serviceKey: String, deleteOldItem: Bool = false) where T.Source == [String:Any] {
        if let value = dict[serviceKey], let ctx = managedObjectContext {
            let oldItem = self[keyPath: dbKey]
            let updated = T.findAndUpdate(value as? [String:Any], ctx: ctx)
            self[keyPath: dbKey] = updated
            
            if oldItem != updated, deleteOldItem {
                oldItem?.delete()
            }
        }
    }
    
    func parse<T: Fetchable & NSManagedObject>(_ type: T.Type, 
                                               _ dict: [String:Any],
                                               _ dbKey: ReferenceWritableKeyPath<Self, NSSet?>,
                                               _ serviceKey: String,
                                               additional: ((T, [String:Any]) -> ())? = nil,
                                               deleteOldItems: Bool = false) where T.Source == [String:Any] {
        if let value = dict[serviceKey], let ctx = managedObjectContext {
            var array: [[String : Any]] = []
            
            if let value = value as? [[String : Any]] {
                array = value
            } else if let value = value as? [Int64] {
                array = value.map { return ["id" : $0] }
            }
            
            let oldItems: Set<T> = {
                if let items = self[keyPath: dbKey] {
                    return items as! Set<T>
                }
                return .init()
            }()
            
            let updatedItems = Set(T.parse(array, additional: additional, ctx: ctx))
            self[keyPath: dbKey] = NSSet(set: updatedItems)
            
            if deleteOldItems {
                oldItems.subtracting(updatedItems).forEach { $0.delete() }
            }
        }
    }
}
