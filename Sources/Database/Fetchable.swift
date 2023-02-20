//
//  Fetchable.swift
//

import Foundation
import CoreData

public protocol Fetchable {
    
    var uid: String? { get set }
    func update(_ dict: [AnyHashable : Any])
}

public protocol CustomId {
    
    static func id(from dict: [AnyHashable : Any]) -> String
}

public extension Fetchable {
    
    func parse<U>(_ dict: [AnyHashable : Any], _ keys: [(dbKey: ReferenceWritableKeyPath<Self, U?>, serviceKey: String)], dateConverted: ((String)->(Date?))? = nil) {
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
    
    func parse<U>(_ dict: [AnyHashable : Any], _ keys: [(dbKey: ReferenceWritableKeyPath<Self, U>, serviceKey: String)]) {
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
    
    static func id(serviceObject: [AnyHashable : Any]) -> String? {
        if let item = self as? CustomId.Type {
            return item.id(from: serviceObject)
        }
        
        var uid = serviceObject["uid"] as? String ?? serviceObject["id"] as? String
        
        if uid == nil, let id = serviceObject["id"] as? Int64 {
            uid = "\(id)"
        }
        if uid == nil {
            print("ID is not found, throwed by class: \(String(describing: self))")
        }
        return uid
    }
}

public protocol FetchableValidation {
    
    static func isValid(dict: [String : Any]) -> Bool
}

public extension Fetchable where Self: NSManagedObject {
    
    func parse<T: Fetchable & NSManagedObject>(_ dict: [String:Any], _ dbKey: ReferenceWritableKeyPath<Self, T?>, _ serviceKey: String) {
        if let value = dict[serviceKey], let ctx = managedObjectContext {
            self[keyPath: dbKey] = T.findAndUpdate(serviceObject: value as? [String:Any], ctx: ctx)
        }
    }
    
    func parse<T: Fetchable & NSManagedObject>(_ dict: [String:Any], _ dbKey: ReferenceWritableKeyPath<Self, Set<T>?>, _ serviceKey: String) {
        if let value = dict[serviceKey], let ctx = managedObjectContext {
            var array: [[String : Any]] = []
            
            if let value = value as? [[String : Any]] {
                array = value
            } else if let value = value as? [Int64] {
                array = value.map { return ["id" : $0] }
            }
            self[keyPath: dbKey] = Set(T.parse(array, ctx: ctx))
        }
    }
    
    static func parse(_ array: [[String:Any]]?, additional: ((Self, [String:Any])->())? = nil, ctx: NSManagedObjectContext) -> [Self] {
        guard let array = array else {
            return []
        }
        var resultSet = Set<String>()
        var result: [Self] = []
        
        for serviceObject in array {
            if let object = findAndUpdate(serviceObject: serviceObject, ctx: ctx),
               !resultSet.contains(object.uid!) {
                resultSet.insert(object.uid!)
                result.append(object)
            }
        }
        return result
    }
    
    static func findOrCreatePlaceholder(uid: String?, ctx: NSManagedObjectContext) -> Self? {
        guard let uid = uid else {
            return nil
        }
        var object: Self
        
        if let found = findFirst(ctx: ctx, "uid == %@", uid) {
            object = found
        } else {
            object = self.init(context: ctx)
            object.uid = uid
        }
        return object
    }
    
    static func findAndUpdate(serviceObject: [String:Any]?, ctx: NSManagedObjectContext) -> Self? {
        guard let serviceObject = serviceObject else {
            return nil
        }
        
        if let type = self as? FetchableValidation.Type, type.isValid(dict: serviceObject) == false {
            return nil
        }
        
        guard let uid = id(serviceObject: serviceObject),
              let object = findOrCreatePlaceholder(uid: uid, ctx: ctx) else {
            return nil
        }
        
        object.update(serviceObject)
        return object
    }
}
