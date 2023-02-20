//
//  NSManagedObjectContext+DatabaseKit.swift
//  DatabaseKit
//
//  Created by Ilya Kuznetsov on 11/22/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData
import os.log

public extension NSManagedObjectContext {
    
    var isViewContext: Bool { name == "view" }
    
    func execute<T: NSManagedObject>(request: NSFetchRequest<T>) throws -> [T] {
        request.entity = NSEntityDescription.entity(forEntityName: String(describing: T.self), in: self)!
        return try fetch(request)
    }
    
    private static var ignoreMergeKey = "ignoreMerge"
    
    internal var ignoreMerge: Bool {
        get { objc_getAssociatedObject(self, &NSManagedObjectContext.ignoreMergeKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &NSManagedObjectContext.ignoreMergeKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    func saveAll() {
        precondition(concurrencyType != .mainQueueConcurrencyType, "View context cannot be saved")
        
        if hasChanges {
            performAndWait {
                do {
                    try save()
                    
                    if let parent = parent {
                        parent.performAndWait {
                            if parent.hasChanges {
                                do {
                                    self.ignoreMerge = true
                                    try parent.save()
                                    self.ignoreMerge = false
                                } catch {
                                    os_log("%@\n%@", error.localizedDescription, (error as NSError).userInfo)
                                }
                            }
                        }
                    }
                } catch {
                    os_log("%@\n%@", error.localizedDescription, (error as NSError).userInfo)
                }
            }
        }
    }
}
