import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    let container = CKContainer(identifier: "iCloud.campbell.PrepItKitchen")
    let publicDB: CKDatabase

    private init() {
        self.publicDB = container.publicCloudDatabase
        print("CloudKitManager using container: \(container.containerIdentifier ?? "unknown") scope: PUBLIC")
    }
}
