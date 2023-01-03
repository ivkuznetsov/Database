# Database
>A CoreData wrapper with convenient interface and multithreading support.

Create database:

```swift
let database = Database()
```

A database.viewContext is readonly context. It is designed only for retrieving the data and presenting it in the UI. 
All the changes are made using the private contexts asynchronously by the supplied interface.

Retrieving managed objects from persistent storage:

```swift
let objects = database.viewContext.all(Model.self)
```

It's better to retrieve objects with some complex filtering in background context to prevent freezing the ui:

```swift
database.fetch { ctx in
    let ids = ctx.find(Model.self, \.text, "some text").ids
    
    DispatchQueue.main.async {
        let objects = database.viewContext.objectsWith(ids: ids)
    }
}
```

Creating new object in persistent storage:

```swift
database.edit { ctx in
    ctx.create(Model.self)
}
```

Editing an existing object:

```swift
let object: Model

database.editWith(object) { object, ctx in
    object.value = "new"
}
```

##Observing changes

The editing happens asynchronously. When the changes are saved in persistent storage, the objects in viewContext will fetch the updates. To react on these changes you can use Combine, or subscribe to object updates by:

```swift
model.add(observer: self) { notification in
    
}
```

You can subscribe to notifications about new/deleted/updated objects of specified NSManagedObject

```swift
User.add(observer: self, closure: { notification in
    
}
```

Or several classes. In the notification you can retrieve the ObjectIds of the objects with changes

```swift
NSManagedObject.add(observer: self, closure: { notification in
    
}, classes: [User.self, Post.self, Commit.self])
```

You can use a @DBObservable property wrapper to handle changes of the managed object:

```swift
@DBObservable var object: Model?

_object.didChange = { replaced in
    // update the UI
}
```

##Database + Work

The Database also has an NSOperation interface for fetching and editing. It uses a Work wrapper implemented in CommonUtils package.
With this you can easily interact with managed objects in the operation chains.

```swift
func retrieveObjectsFromBackend() -> Work<[[String:Any]]> {
    // do the network request
}

let work = retrieveObjectsFromBackend().then { array in
    self.database.editOp { ctx in
        // parse managed objects from the array
    }
}

work.runWith { error in
    
}
```

## CodableTransformer

You can store Swift Codable types in transformable properties by using Database.CodableTransformer. 
The only requirement is that the root object was inherited from NSObject:

```swift
class SomeObject: NSObject, Codable {
    
    let swiftStruct: [SomeStruct]
    let swiftEnum: [SomeEnum]
    //etc
}
```

## Meta

Ilya Kuznetsov – i.v.kuznecov@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/ivkuznetsov](https://github.com/ivkuznetsov)
