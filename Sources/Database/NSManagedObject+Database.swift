//
//  NSManagedObject+DatabaseKit.swift
//

import Foundation
import CoreData
import os.log

public extension NSManagedObject {
    
    func delete() {
        managedObjectContext?.delete(self)
    }
    
    var isObjectDeleted: Bool { managedObjectContext == nil || isDeleted }
    
    var permanentObjectID: NSManagedObjectID {
        var objectID = self.objectID
        
        if objectID.isTemporaryID {
            try? managedObjectContext?.obtainPermanentIDs(for: [self])
            objectID = self.objectID
        }
        return objectID
    }
    
    class func idsWith<T: Sequence>(objects: T) -> [NSManagedObjectID] where T.Element: NSManagedObject {
        objects.map { $0.permanentObjectID }
    }
    
    class func uriWith<T: Sequence>(ids: T) -> [URL] where T.Element: NSManagedObjectID {
        ids.map { $0.uriRepresentation() }
    }    
}
