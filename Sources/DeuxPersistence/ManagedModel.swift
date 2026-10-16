import CoreData

/// Every record is reachable from its household. Inverses and optional properties
/// allow Core Data to mirror the same graph into a CloudKit share.
enum ManagedModel {
    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let household = entity("HouseholdRecord", attributes: [
            attribute("id", .UUIDAttributeType), attribute("name", .stringAttributeType),
            attribute("personOneName", .stringAttributeType), attribute("personTwoName", .stringAttributeType),
            attribute("createdAt", .dateAttributeType)
        ])
        let task = entity("TaskRecord", attributes: [attribute("id", .UUIDAttributeType), attribute("payload", .binaryDataAttributeType)])
        let completion = entity("CompletionRecord", attributes: [attribute("id", .UUIDAttributeType), attribute("payload", .binaryDataAttributeType)])
        connect(household, name: "tasks", child: task)
        connect(household, name: "completions", child: completion)
        model.entities = [household, task, completion]
        return model
    }

    private static func entity(_ name: String, attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let result = NSEntityDescription()
        result.name = name
        result.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        result.properties = attributes
        return result
    }

    private static func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
        let result = NSAttributeDescription()
        result.name = name
        result.attributeType = type
        result.isOptional = true
        return result
    }

    private static func connect(_ root: NSEntityDescription, name: String, child: NSEntityDescription) {
        let children = NSRelationshipDescription()
        children.name = name
        children.destinationEntity = child
        children.minCount = 0
        children.maxCount = 0
        children.isOptional = true
        children.deleteRule = .cascadeDeleteRule
        let parent = NSRelationshipDescription()
        parent.name = "household"
        parent.destinationEntity = root
        parent.minCount = 0
        parent.maxCount = 1
        parent.isOptional = true
        parent.deleteRule = .nullifyDeleteRule
        children.inverseRelationship = parent
        parent.inverseRelationship = children
        root.properties.append(children)
        child.properties.append(parent)
    }
}
