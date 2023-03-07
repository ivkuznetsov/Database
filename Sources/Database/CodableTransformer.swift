//
//  CodableTransformer.swift
//

import Foundation
import CommonUtils

public class CodableTransformer: ValueTransformer {
    
    private indirect enum Value: Codable {
        case string(String)
        case number(Data)
        case codableObject(base64: String, name: String)
        case array([Value])
        case dictionary([String:Value])
        
        init?(value: Any) {
            if let value = value as? String {
                self = .string(value)
            } else if let value = value as? NSNumber {
                self = .number(try! JSONSerialization.data(withJSONObject: [value]))
            } else if let value = value as? [NSNumber] {
                self = .array(value.compactMap { Value(value: $0) })
            } else if let value = value as? [String] {
                self = .array(value.compactMap { Value(value: $0) })
            } else if let value = value as? [Encodable] {
                self = .array(value.compactMap { Value(value: $0) })
            } else if let value = value as? AnyObject & Encodable {
                self = .codableObject(base64: try! value.toData().base64EncodedString(), name: NSStringFromClass(type(of: value)))
            } else if let value = value as? [String:Any] {
                self = .dictionary(value.reduce(into: [:], { result, item in
                    if let value = Value(value: item.value) {
                        result[item.key] = value
                    }
                }))
            } else {
                return nil
            }
        }
        
        var object: Any {
            switch self {
            case .string(let string):
                return string
            case .number(let number):
                return (try! JSONSerialization.jsonObject(with: number) as? [NSNumber])!.first!
            case .array(let array):
                return array.map { $0.object }
            case .dictionary(let dict):
                return dict.reduce(into: [:], { result, item in
                    result[item.key] = item.value.object
                })
            case .codableObject(let base64, let className):
                let data = Data(base64Encoded: base64)!
                let classObject = NSClassFromString(className) as! Decodable.Type
                return try! classObject.decode(data)
            }
        }
    }
    
    public override class func transformedValueClass() -> AnyClass { NSData.self }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? Data else { return nil }
        return try? Value.decode(value).object
    }

    public override class func allowsReverseTransformation() -> Bool { true }

    public override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value, let encodingValue = Value(value: value) else { return nil }
        return try! encodingValue.toData()
    }
}
