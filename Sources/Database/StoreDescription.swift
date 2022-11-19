//
//  StoreDescription.swift
//

import Foundation
import CoreData
import CommonUtils

public struct StoreDescription {
    
    let url: URL
    let storeType: String
    let configuration: String
    let readOnly: Bool
    let deleteOnError: Bool
    let options: [String : Any]
    
    public init(url: URL,
                storeType: String = NSSQLiteStoreType,
                configuration: String = "PF_DEFAULT_CONFIGURATION_NAME",
                readOnly: Bool = false,
                deleteOnError: Bool = true,
                options: [String : Any] = [:]) {
        self.url = url
        self.storeType = storeType
        self.configuration = configuration
        self.readOnly = readOnly
        self.deleteOnError = deleteOnError
        self.options = options
    }
    
    public static var appDataStore: StoreDescription {
        let url = URL(fileURLWithPath: FileManager.applicationSupportDirectory + "/" + databaseFileName)
        return StoreDescription(url: url)
    }
    
    public static var userDataStore: StoreDescription {
        let url = URL(fileURLWithPath: FileManager.applicationSupportDirectory + "/" + databaseFileName)
        return StoreDescription(url: url, deleteOnError: false)
    }
    
    public static var transientStore: StoreDescription {
        StoreDescription(url: URL(string: "memory://")!, storeType: NSInMemoryStoreType)
    }
    
    fileprivate static var databaseFileName: String {
        ProcessInfo.processInfo.processName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) + ".sqlite"
    }
    
    public func copyStoreFileFrom(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.copyItem(at: url, to: self.url)
        }
    }
    
    public func removeStoreFiles() {
        let dataBaseDirectory = url.deletingLastPathComponent()
        
        if let filePathes = try? FileManager.default.contentsOfDirectory(atPath: dataBaseDirectory.path) {
            for fileName in filePathes {
                if fileName.contains(type(of: self).databaseFileName) {
                    try? FileManager.default.removeItem(at: dataBaseDirectory.appendingPathComponent(fileName))
                }
            }
        }
    }
}
