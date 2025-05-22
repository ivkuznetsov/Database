//
//  CodableTransformer.swift
//

import Foundation

public class CodableTransformer: ValueTransformer {
    
    public indirect enum Value: Codable {
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
        
        func object() throws -> Any {
            switch self {
            case .string(let string):
                return string
            case .number(let number):
                return (try! JSONSerialization.jsonObject(with: number) as? [NSNumber])!.first!
            case .array(let array):
                return array.compactMap { try? $0.object() }
            case .dictionary(let dict):
                return dict.reduce(into: [:], { result, item in
                    result[item.key] = try? item.value.object()
                })
            case .codableObject(let base64, let className):
                let data = Data(base64Encoded: base64)!
                
                if let classObject = NSClassFromString(className) as? Decodable.Type {
                    do {
                        return try classObject.decode(data)
                    } catch {
                        print("Cannot decode object of class: \(className), error: \(error)")
                        throw error
                    }
                } else {
                    print("Cannot find class \(className) for decoding object")
                    return data
                }
            }
        }
    }
    
    public override class func transformedValueClass() -> AnyClass { NSData.self }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? Data else { return nil }
        return try? Value.decode(value).object()
    }

    public override class func allowsReverseTransformation() -> Bool { true }

    public override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value, let encodingValue = Value(value: value) else { return nil }
        return try! encodingValue.toData()
    }
}

private extension Encodable {
    
    func toData(_ encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

private extension Decodable {
    
    static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> Self {
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(self, from: data)
    }
    
    static func decode(_ dict: [String : Any]) throws -> Self {
        let data = try Foundation.JSONSerialization.data(withJSONObject: dict, options: [])
        return try decode(data)
    }
}
