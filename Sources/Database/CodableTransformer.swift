//
//  CodableTransformer.swift
//

import Foundation
import CommonUtils

public class CodableTransformer: ValueTransformer {
    
    public override class func transformedValueClass() -> AnyClass { NSData.self }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? Data else { return nil }
        
        let dict = try! JSONSerialization.jsonObject(with: value, options: []) as! [String: String]
        let className = dict.keys.first!
        let dataString = dict.values.first!
        
        let data = Data(base64Encoded: dataString)!
        
        if let classObject = NSClassFromString(className) as? Decodable.Type {
            return try! classObject.decode(data)
        }
        return nil
    }

    public override class func allowsReverseTransformation() -> Bool { true }

    public override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? AnyObject & Encodable else { return nil }
        
        let className = NSStringFromClass(type(of: value))
        let jsonData = try! value.toData()
        
        let dict: [String: String] = [className : jsonData.base64EncodedString()]
        
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }
}
