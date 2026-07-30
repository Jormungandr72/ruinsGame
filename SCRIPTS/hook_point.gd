class_name HookPoint
extends Marker2D

"""Marks an adjustable point on any game object as grappleable."""

const HOOK_POINT_GROUP: StringName = &"hook_points"

@export var enabled: bool = true
@export var attached_object_path: NodePath = NodePath("..")


func _enter_tree() -> void:
	"""Registers this marker for discovery by hook controllers."""

	add_to_group(HOOK_POINT_GROUP)


func getAttachedObject() -> Node:
	"""Returns the object whose collision may be hit by the hook ray."""

	return get_node_or_null(attached_object_path)


func acceptsCollider(collider: Node) -> bool:
	"""Returns true when a ray collider belongs to the attached object."""

	var attached_object := getAttachedObject()
	if attached_object == null or collider == null:
		return false

	return (
		collider == attached_object
		or attached_object.is_ancestor_of(collider)
	)
