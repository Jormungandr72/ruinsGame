class_name CameraController
extends Camera2D

"""Smoothly follows a target only after it leaves an adjustable dead zone."""

@export var target_path: NodePath = NodePath("..")
@export var target_offset: Vector2 = Vector2(-6.0, 13.0)
@export var dead_zone_size: Vector2 = Vector2(120.0, 80.0)
@export_range(0.0, 30.0, 0.1) var follow_speed: float = 8.0
@export var maximum_follow_distance: Vector2 = Vector2(420.0, 280.0)
@export var snap_to_target_on_ready: bool = true

var target: Node2D


func _ready() -> void:
	"""Finds the target and separates the camera from parent movement."""

	target = get_node_or_null(target_path) as Node2D
	if target == null:
		push_error("CameraController could not find its follow target.")
		set_physics_process(false)
		return

	top_level = true
	if snap_to_target_on_ready:
		global_position = target.global_position + target_offset


func _physics_process(delta: float) -> void:
	"""Interpolates toward the nearest position containing the target."""

	if target == null:
		return

	var target_position := target.global_position + target_offset
	var half_dead_zone := dead_zone_size.abs() * 0.5
	var target_from_camera := target_position - global_position
	var desired_position := global_position

	if absf(target_from_camera.x) > half_dead_zone.x:
		desired_position.x = (
			target_position.x
			- signf(target_from_camera.x) * half_dead_zone.x
		)

	if absf(target_from_camera.y) > half_dead_zone.y:
		desired_position.y = (
			target_position.y
			- signf(target_from_camera.y) * half_dead_zone.y
		)

	var interpolation_weight := 1.0
	if follow_speed > 0.0:
		interpolation_weight = 1.0 - exp(-follow_speed * delta)

	var interpolated_position := global_position.lerp(
		desired_position,
		interpolation_weight
	)
	var maximum_distance := Vector2(
		maxf(absf(maximum_follow_distance.x), half_dead_zone.x),
		maxf(absf(maximum_follow_distance.y), half_dead_zone.y)
	)
	var camera_from_target := interpolated_position - target_position
	camera_from_target.x = clampf(
		camera_from_target.x,
		-maximum_distance.x,
		maximum_distance.x
	)
	camera_from_target.y = clampf(
		camera_from_target.y,
		-maximum_distance.y,
		maximum_distance.y
	)
	global_position = target_position + camera_from_target
