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
let objects = Model.all(database.viewContext)
```

It's better to retrieve objects with some complex filtering in background context to prevent freezing the ui:

```swift
let objects = try await database.fetch { ctx in
   Model.find(\.text, "some text", ctx: ctx).ids
}.objects(database.viewContext)
```

Create a new object in the persistent storage:

```swift
try await database.edit { ctx in
    Model(context: ctx)
}
```

Edit an existing object:

```swift
let object: Model

try await object.edit(database) { object, ctx in
    object.value = "new"
}
```

## Observing changes

The editing happens asynchronously. When the changes are saved in the persistent storage, the objects in viewContext will fetch the updates. To react on these changes you can use objectWillChange publisher:

```swift
model.objectWillChange.sink {
    
}
```

You can subscribe to publisher about new/deleted/updated objects of specified NSManagedObject

```swift
User.objectsDidChange(database).sink { change in

}
```

Or several classes. In the notification you can retrieve the ObjectIds of the objects with changes

```swift
[User.self, Post.self, Commit.self].objectsDidChange(database).sink { change in

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
