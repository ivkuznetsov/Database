//
//  DBObservable.swift
//

import Foundation
import CoreData

@propertyWrapper
public class DBObservable<T: NSManagedObject> {
    private var value: T?
    
    public var didChange: ((_ valueReplaced: Bool)->())?
    
    public init(wrappedValue value: T?) {
        self.value = value
    }
    
    public var wrappedValue: T? {
        get { value }
        set {
            if value != newValue {
                value = newValue
                value?.remove(observer: self)
                value?.add(observer: self, closure: { [unowned self] _ in
                    if self.value?.isObjectDeleted == true {
                        self.wrappedValue = nil
                    } else {
                        self.valueDidChange(replaced: false)
                    }
                })
                valueDidChange(replaced: true)
            }
        }
    }
    
    private func valueDidChange(replaced: Bool) {
        didChange?(replaced)
        
        keyPathObservers.values.forEach { wrapper in
            if wrapper.isValueChanged() {
                wrapper.didChange()
            }
        }
    }
    
    private var keyPathObservers: [AnyKeyPath : ObserveWrapper] = [:]
    
    private struct ObserveWrapper {
        let didChange: ()->()
        let isValueChanged: ()->Bool
    }
    
    public func observe<E: Equatable>(_ keyPath: KeyPath<T, E>, didChange: @escaping ()->()) {
        let currentValue = value?[keyPath: keyPath]
        let wrapper = ObserveWrapper(didChange: didChange, isValueChanged: { [weak self] in
            guard let wSelf = self else { return false }
            
            let newValue = wSelf.value?[keyPath: keyPath]
            wSelf.observe(keyPath, didChange: didChange)
            
            return currentValue != newValue
        })
        keyPathObservers[keyPath] = wrapper
    }
}
