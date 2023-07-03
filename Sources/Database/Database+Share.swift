//
//  Database+Share.swift
//  
//
//  Created by Ilya Kuznetsov on 26/06/2023.
//

import Foundation
import CoreData
import CloudKit
import CommonUtils

extension CKShare: @unchecked Sendable { }

extension CKShare.Metadata: @unchecked Sendable { }

@available(iOS 16.0, *)
public extension Database {
    
    func makeShare(_ destination: NSManagedObject, title: String? = nil, icon: Data? = nil) async throws -> CKShare {
        try await makeShare([destination], title: title, icon: icon)
    }
    
    func makeShare(_ destinations: [NSManagedObject], title: String? = nil, icon: Data? = nil) async throws -> CKShare {
        let (_, share, _) = try await container.share(destinations, to: nil)
        configure(share: share, title: title, icon: icon)
        return share
    }
    
    private func configure(share: CKShare, title: String?, icon: Data?) {
        share[CKShare.SystemFieldKey.title] = title
        share[CKShare.SystemFieldKey.thumbnailImageData] = icon
    }
    
    func removeSelfFromParticipants(share: CKShare) async throws {
        guard let store = sharedStore else { return }
        
        try await container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store)
    }
    
    func makeShareOrFetch(_ destination: NSManagedObject, title: String? = nil, icon: Data? = nil) async throws -> CKShare {
        if let share = try container.fetchShares(matching: [destination.objectID])[destination.objectID] {
            configure(share: share, title: title, icon: icon)
            return share
        }
        return try await makeShare(destination, title: title, icon: icon)
    }
    
    func fetchShare(_ destination: NSManagedObject) -> CKShare? {
        do {
            return try container.fetchShares(matching: [destination.objectID])[destination.objectID]
        } catch {
            print("\(error.localizedDescription)")
        }
        return nil
    }
    
    func isShared(_ object: NSManagedObject) -> Bool {
        isShared(object.objectID)
    }
    
    func isShared(_ objectID: NSManagedObjectID) -> Bool {
        if let persistentStore = objectID.persistentStore {
            return persistentStore == self.sharedStore
        } else {
            do {
                let shares = try container.fetchShares(matching: [objectID])
                return shares.count > 0
            } catch {
                print("Failed to fetch share for \(objectID): \(error)")
            }
        }
        return false
    }
    
    var cloudKitContainer: CKContainer? {
        for description in container.persistentStoreDescriptions {
            if let identifier = description.cloudKitContainerOptions?.containerIdentifier {
                return CKContainer(identifier: identifier)
            }
        }
        return nil
    }
    
    func accept(_ metadata: CKShare.Metadata) async throws {
        guard let sharedStore = sharedStore else { throw RunError.custom("Please setup iCloud account") }
        
        try await container.acceptShareInvitations(from: [metadata], into: sharedStore)
    }
    
    private func persistentStoreForShare(with shareRecordID: CKRecord.ID) -> NSPersistentStore? {
        if let store = privateStore, let shares = try? container.fetchShares(in: store) {
            if shares.contains(where: { $0.recordID.zoneID == shareRecordID.zoneID }) {
                return store
            }
        }
        if let store = sharedStore, let shares = try? container.fetchShares(in: store) {
            if shares.contains(where: { $0.recordID.zoneID == shareRecordID.zoneID }) {
                return store
            }
        }
        return nil
    }
}
