import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    init() {
        container = NSPersistentCloudKitContainer(name: "ThunderGallery")
        
        // Configure the persistent store
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.type = NSSQLiteStoreType
        
        // Configure CloudKit integration
        let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.sougata.Thunder-Gallery"
        )
        storeDescription.cloudKitContainerOptions = cloudKitContainerOptions
        
        // Enable remote change notifications
        storeDescription.setOption(true as NSNumber, 
                                 forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Set the store description
        container.persistentStoreDescriptions = [storeDescription]
        
        // Load the persistent store
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Core Data Saving support
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
} 