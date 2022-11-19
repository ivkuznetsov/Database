//
//  NSManagedObject+Notifications.swift
//

import Foundation
import CoreData
import CommonUtils

public extension NSManagedObject {

    func add(observer: AnyObject, closure: @escaping (AppNotification?)->()) {
        let uri = objectID.uriRepresentation()
        type(of: self).add(observer: observer) { notification in
            if notification?.deleted.contains(uri) == true || notification?.updated.contains(uri) == true {
                closure(notification)
            }
        }
    }
    
    func remove(observer: AnyObject) {
        type(of: self).remove(observer: observer)
    }
    
    static func add(observer: AnyObject, closure: @escaping (AppNotification?)->()) {
        add(observer: observer, closure: closure, classes: [self])
    }
    
    static func remove(observer: AnyObject) {
        remove(observer: observer, classes: [self])
    }
    
    static func add(observer: AnyObject, closure: @escaping (AppNotification?)->(), classes: [NSManagedObject.Type]) {
        NotificationManager.shared.add(observer, closure: closure, names: classNamesFor(classes: classes))
    }
    
    static func remove(observer: AnyObject, classes: [NSManagedObject.Type]) {
        NotificationManager.shared.remove(observer: observer, names: classNamesFor(classes: classes))
    }
    
    static func postUpdatesFor(classes: [NSManagedObject.Type], notification: AppNotification?) {
        NotificationManager.shared.postNotification(names: classNamesFor(classes: classes), notification: notification)
    }
    
    static func post(notification: AppNotification? = nil) {
        NotificationManager.shared.postNotification(names: classNamesFor(classes: [self]), notification: notification)
    }
    
    //Can be performed from any context
    func post() {
        type(of: self).post(notification: AppNotification(updated: Set([objectID.uriRepresentation()])))
    }
    
    private static func classNamesFor(classes: [NSManagedObject.Type]) -> [String] {
        classes.map { String(describing: $0) }
    }
}
