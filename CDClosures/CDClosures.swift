//
//  CDClosures.swift
//  CDClosures
//
//  Created by YLCHUN on 2018/7/18.
//  Copyright © 2018年 ylchun. All rights reserved.
//

import Foundation
import CoreData

private func cdcTrydo(msg:String? = nil, lock:NSLock? = nil, try:() throws -> Void) -> NSError? {
    do {
        lock?.lock()
        try `try`()
        lock?.unlock()
        return nil
    } catch let err as NSError {
        guard let msg = msg else {return err}
        return NSError(domain: "\(msg): \(err.domain)", code: err.code, userInfo: err.userInfo)
    }
}

fileprivate extension NSError {
    convenience init(_ domain:String, _ code:Int) {
        self.init(domain: domain, code: code, userInfo: nil)
    }
}

fileprivate extension NSManagedObjectContext
{
    class func `init`(name:String) throws -> NSManagedObjectContext {
        if #available(iOS 10.0, *) {
            return try managedObjectContext_10(name)
        } else {
            return try managedObjectContext_9(name)
        }
    }
    
    private static func managedObjectContext_9(_ name:String) throws -> NSManagedObjectContext {
        guard let url = Bundle.main.url(forResource: name, withExtension: "momd")
            else { throw NSError("unfind momd: \"\(name)\"", 401) }
        guard let model = NSManagedObjectModel(contentsOf: url)
            else { throw NSError("can't init NSManagedObjectModel whith momd: \"\(name)\"", 402) }
    
        guard let sqlpath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            else { throw NSError("can't save sqlite to document directory", 403) }
        var sqlurl = URL(fileURLWithPath: sqlpath)
        sqlurl.appendPathComponent("\(name)_cdc.sqlite")
        let store = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options = [NSMigratePersistentStoresAutomaticallyOption:true,
         NSInferMappingModelAutomaticallyOption:true]
        try store.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: sqlurl, options: options)
    
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = store;
        return context
    }
    
    @available(iOS 10.0, *)
    private static func managedObjectContext_10(_ name:String) throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: name)
        var err:NSError?
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            err = error as NSError?
        })
        if let err = err { throw err }
        let context:NSManagedObjectContext? = container.viewContext
        guard let ctx = context
            else { throw NSError("unfind momd: \"\(name)\"", 401) }
        return ctx
    }
    
    func entityMap () -> [String:String] {
        var map:[String:String] = [:]
        if let store = self.persistentStoreCoordinator {
            let entities = store.managedObjectModel.entities
            for entitie in entities {
                if let className = entitie.managedObjectClassName {
                    let name = entitie.name
                    map[className] = name ?? className
                }
            }
        }
        return map
    }
}

enum CDCSortOp {
    case desc
    case asc
}
typealias CDCSort = (key:String, value:CDCSortOp)
typealias CDCRange = (loc:UInt, len:UInt)

fileprivate class CDClosures
{
    fileprivate static var modelMap:[String:String] = [:]//className:fileName
    private static var initlock = NSLock()
    private static var map:[String: CDClosures] = [:]//entityName:CDClosures
    
    static func `init`(name:String) throws -> CDClosures {
        initlock.lock()
        var err:NSError?
        var help:CDClosures? = map[name]
        if let _ = help {

        } else {
           err = cdcTrydo {
                let context = try NSManagedObjectContext.init(name:name)
                help = CDClosures(name, context)
                map[name] = help
            }
        }
        initlock.unlock()
        if let err = err { throw err }
        return help!
    }
    
    private var name:String
    private let lock = NSLock()
    private var context:NSManagedObjectContext
    private var entityMap:[String:String]
    private init(_ name:String, _ context:NSManagedObjectContext) {
        self.name = name
        self.context = context
        self.entityMap = context.entityMap()
        for (k, _) in self.entityMap {
            CDClosures.modelMap.updateValue(name, forKey: k)
        }
    }
    
    private func entityName<T:NSManagedObject>(_ :T.Type) -> String {
        let className = "\(T.self)"
        guard let name = entityMap[className] else {
            return className;
        }
        return name
    }

    private func fetchRequest<T:NSManagedObject>(_ :T.Type, `where`:String? = nil, range:CDCRange? = nil, groupBy:[String]? = nil, sorts:[CDCSort]? = nil) -> NSFetchRequest<T> {
        var request:NSFetchRequest<T>
        if #available(iOS 10.0, *) {
            request = T.fetchRequest() as! NSFetchRequest<T>
        } else {
            request = NSFetchRequest<T>(entityName: entityName(T.self))
        }
        
        if let `where` = `where`, `where`.count > 0 {
            let predicate = NSPredicate(format:`where`, argumentArray: nil)
            request.predicate = predicate
        }
        
        if let range = range, range.len > 0 {
            request.fetchOffset = Int(range.loc)
            request.fetchLimit = Int(range.len)
        }
        
        if let groupBy = groupBy, groupBy.count > 0  {
            request.propertiesToGroupBy = groupBy
        }
        
        if let sorts = sorts, sorts.count > 0 {
            request.sortDescriptors = sorts.map { NSSortDescriptor(key: $0.key, ascending: $0.value == .asc) }
        }
        return request
    }
    
    private func select<T:NSManagedObject>(_:T.Type, `where`:String? = nil, range:CDCRange? = nil, groupBy:[String]? = nil, sorts:[CDCSort]? = nil) throws -> [T] {
        let request = fetchRequest(T.self, where:`where`, range:range, groupBy:groupBy, sorts:sorts)
        return try context.fetch(request)
    }
    
    @available(iOS 9.0, *)
    private func batchDelete<T:NSManagedObject>(_:T.Type, `where`:String? = nil) throws -> Int {
        let request = fetchRequest(T.self, where:`where`)
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
        batchDelete.resultType = .resultTypeCount
        guard let store = context.persistentStoreCoordinator
            else { throw NSError("unfine persistentStoreCoordinator", 98) }
        let result = try store.execute(batchDelete, with: context) as? NSBatchDeleteResult
        guard let count = (result?.result as? NSNumber)?.intValue
            else { return 0 }
        return count
    }
    
    private func ordinaryDelete<T:NSManagedObject>(_:T.Type, `where`:String? = nil) throws -> Int {
        let ts = try select(T.self, where: `where`)
        for t in ts {
            context.delete(t)
        }
        return ts.count
    }
    
    private func resetIfNeed(_ need:Bool) {
        if !need || !context.hasChanges { return }
        context.reset()
    }
    
    private func seveIfNeed(_ need:Bool)throws {
        if !need || !context.hasChanges { return }
        try context.save()
    }
    
    public var aoutSave = true
    
    func save()throws {
        if let err = (cdcTrydo(msg: "save error", lock: lock) {
            try seveIfNeed(true)
        }){ throw err }
    }
    
    func reset() {
        lock.lock()
        resetIfNeed(true)
        lock.unlock()
    }
    
    func select<T:NSManagedObject>(_:T.Type, `where`:String? = nil, range:CDCRange? = nil, groupBy:[String]? = nil, sorts:[CDCSort]? = nil, cb:([T])->Void)throws {
        if let err = (cdcTrydo(msg: "select error", lock: lock) {
            let ts = try select(T.self, where: `where`, range: range, groupBy:groupBy, sorts: sorts)
            cb(ts)
        }){ throw err }
    }
    
    func update<T:NSManagedObject>(_:T.Type, `where`:String? = nil, cb:(T)->Void) throws {
        if let err = (cdcTrydo(msg: "update error", lock: lock) {
            let ts = try select(T.self, where: `where`)
            for t in ts {
                cb(t)
            }
            try seveIfNeed(aoutSave)
            print("update count: \(ts.count)")
        }){ throw err }
    }
    
    func batchUpdate<T:NSManagedObject>(_:T.Type, update:[String : Any]) throws {
        if let err = (cdcTrydo(msg: "batchUpdate error", lock: lock) {
            let batchUpdate = NSBatchUpdateRequest(entityName: entityName(T.self))
            batchUpdate.propertiesToUpdate = update
            batchUpdate.affectedStores = context.persistentStoreCoordinator!.persistentStores
            batchUpdate.resultType = .updatedObjectsCountResultType
            let result = try context.execute(batchUpdate) as? NSBatchUpdateResult
            try seveIfNeed(aoutSave)
            if let count = (result?.result as? NSNumber)?.intValue {
                print("batchUpdate count: \(count)")
            }
        }){ throw err }
    }
    
    func insert<T:NSManagedObject>(_:T.Type, count:Int, cb:(Int, T)->Void) throws {
        if let err = (cdcTrydo(msg: "insert error", lock: lock) {
            let emptyName = entityName(T.self)
            guard let endesc = NSEntityDescription.entity(forEntityName: emptyName, in: context)
                else { throw NSError("unfind entity: \"\(emptyName)\".", 99) }
            for i in 0..<count {
                let t = T(entity: endesc, insertInto: context)
                cb(i,t);
                context.insert(t)
            }
            try seveIfNeed(true)
        }){ throw err }
    }
    
    func insert<T:NSManagedObject>(_:T.Type, cb:(T)->Void)throws {
        try insert(T.self, count: 1) { (idx, t) in
            cb(t)
        }
    }

    func delete<T:NSManagedObject>(_:T.Type, `where`:String? = nil) throws {
        if let err = (cdcTrydo(msg: "delete error", lock: lock) {
            let count:Int
            if #available(iOS 9.0, *) {
                count = try batchDelete(T.self, where:`where`)
            } else {
                count = try ordinaryDelete(T.self, where:`where`)
            }
            try seveIfNeed(aoutSave)
            print("delete count: \(count)")
        }){ throw err }
    }
    
    func frc<T:NSManagedObject>(_:T.Type, delegate:NSFetchedResultsControllerDelegate, sectionNameKeyPath:String? = nil, `where`:String? = nil, range:CDCRange? = nil, groupBy:[String]? = nil, sorts:[CDCSort]? = nil) -> NSFetchedResultsController<T> {
        let request = fetchRequest(T.self, where:`where`, range:range, sorts:sorts)
        let fetchResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName:nil)
        fetchResultsController.delegate = delegate
        return fetchResultsController;
    }
    
}

protocol CDClosuresProtocol {}

func registerCDClosures(_ name:String) throws {
    let _ = try CDClosures.init(name: name)
}

extension CDClosuresProtocol where Self : NSManagedObject
{
    private static func cdClosures() throws -> CDClosures {
        guard let name = CDClosures.modelMap["\(self)"] else {
            throw NSError("unregister CDClosures, please call \"registerCDClosures(fileName)\" at first", 400)
        }
        return try CDClosures.init(name: name)
    }
    
    static func select(`where`:String? = nil, range:CDCRange? = nil, groupBy:[String]? = nil, sorts:[CDCSort]? = nil, cb:([Self])->Void)throws {
        let cdc = try cdClosures()
        try cdc.select(self, where: `where`, range: range, groupBy:groupBy, sorts: sorts, cb: cb)
    }
    
    static func update(`where`:String? = nil, cb:(Self)->Void) throws {
        let cdc = try cdClosures()
        try cdc.update(self, where: `where`, cb: cb)
    }
    
    static func batchUpdate(_ update:[String : Any]) throws {
        let cdc = try cdClosures()
        try cdc.batchUpdate(self, update: update)
    }
    
    static func insert(count: Int, cb: (Int, Self) -> Void) throws {
        let cdc = try cdClosures()
        try cdc.insert(self, count: count, cb: cb)
    }
    
    static func insert(cb: (Self) -> Void) throws {
        let cdc = try cdClosures()
        try cdc.insert(self, cb: cb)
    }
    
    static func delete(`where`: String? = nil) throws {
        let cdc = try cdClosures()
        try cdc.delete(self, where: `where`)
    }
    
    static func frc(delegate:NSFetchedResultsControllerDelegate, sectionNameKeyPath:String? = nil, `where`:String? = nil, range:CDCRange? = nil, groupBy:[String]? = nil, sorts:[CDCSort]? = nil) throws -> NSFetchedResultsController<Self> {
        let cdc = try cdClosures()
        return cdc.frc(self, delegate: delegate, sectionNameKeyPath: sectionNameKeyPath, where: `where`, range: range, groupBy: groupBy, sorts: sorts)
    }
}

extension NSManagedObject:CDClosuresProtocol {}
