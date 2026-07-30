class_name HookController
extends Node2D

"""Provides hook targeting, swing forces, rope constraints, and visuals."""

@export var player_path: NodePath = NodePath("..")
@export var hook_action: StringName = &"hook"
@export var swing_gravity: float = 1100.0
@export var swing_control: float = 950.0
@export var min_rope_length: float = 24.0
@export var max_rope_length: float = 420.0
@export var left_angle_cap_degrees: float = 75.0
@export var right_angle_cap_degrees: float = 75.0
@export var max_swing_speed: float = 700.0
@export_range(0.0, 1.0) var angle_rebound_factor: float = 0.35
@export var release_speed_multiplier: float = 1.0
@export var line_width: float = 4.0
@export var line_color: Color = Color.BLACK

var player: CharacterBody2D
var selected_hook_point: HookPoint
var active_hook_point: HookPoint
var hook_line: Line2D
var anchor_position: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var is_hooked: bool = false


func _ready() -> void:
	"""Finds the player and creates the hook line."""

	findPlayer()
	createHookLine()


func _process(_delta: float) -> void:
	"""Updates the hook preview and active rope line."""

	if player == null:
		findPlayer()
	updateHookLine()


func createHookLine() -> void:
	"""Creates the black placeholder hook line."""

	hook_line = Line2D.new()
	hook_line.top_level = true
	hook_line.z_index = 100
	hook_line.width = line_width
	hook_line.default_color = line_color
	hook_line.visible = false
	add_child(hook_line)


func findPlayer() -> void:
	"""Finds the player controlled by this hook component."""

	player = get_node_or_null(player_path) as CharacterBody2D

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	if player == null:
		player = current_scene.find_child("Player", true, false) as CharacterBody2D


func canStartHook() -> bool:
	"""Finds and stores the nearest reachable, unobstructed hook point."""

	if player == null:
		return false

	selected_hook_point = findNearestValidHookPoint()
	return selected_hook_point != null


func startHook() -> bool:
	"""Attaches the rope to the nearest currently valid hook point."""

	if not canStartHook():
		return false

	active_hook_point = selected_hook_point
	anchor_position = active_hook_point.global_position
	rope_length = player.global_position.distance_to(anchor_position)
	is_hooked = true
	return true


func releaseHook() -> void:
	"""Releases the rope while retaining the player's swing velocity."""

	if not is_hooked:
		return

	is_hooked = false
	active_hook_point = null
	player.velocity *= release_speed_multiplier


func findNearestValidHookPoint() -> HookPoint:
	"""Returns the nearest hook point passing range and visibility checks."""

	var nearest_point: HookPoint
	var nearest_distance := INF

	for node in get_tree().get_nodes_in_group(HookPoint.HOOK_POINT_GROUP):
		var hook_point := node as HookPoint
		if hook_point == null or not hook_point.enabled:
			continue

		var distance := player.global_position.distance_to(
			hook_point.global_position
		)
		if (
			distance < min_rope_length
			or distance > max_rope_length
			or distance >= nearest_distance
		):
			continue

		if not isHookPathClear(hook_point):
			continue

		nearest_point = hook_point
		nearest_distance = distance

	return nearest_point


func isHookPathClear(hook_point: HookPoint) -> bool:
	"""Returns true when nothing blocks the ray to a hook point."""

	if player == null or not is_instance_valid(hook_point):
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		player.global_position,
		hook_point.global_position
	)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider := hit.get("collider") as Node
	if collider == null:
		return false

	return hook_point.acceptsCollider(collider)


func hasClearActiveHookPath() -> bool:
	"""Returns true while the active point exists and remains unobstructed."""

	if not is_instance_valid(active_hook_point):
		return false

	anchor_position = active_hook_point.global_position
	return isHookPathClear(active_hook_point)


func applySwingForces(delta: float, input_direction: float) -> void:
	"""Adds gravity and player-directed tangential swing acceleration."""

	if is_instance_valid(active_hook_point):
		anchor_position = active_hook_point.global_position

	var from_anchor := player.global_position - anchor_position
	if from_anchor.is_zero_approx():
		return

	var radial_direction := from_anchor.normalized()
	var tangent_direction := Vector2(-radial_direction.y, radial_direction.x)
	if tangent_direction.x < 0.0:
		tangent_direction = -tangent_direction

	player.velocity.y += swing_gravity * delta
	player.velocity += tangent_direction * input_direction * swing_control * delta
	player.velocity = player.velocity.limit_length(max_swing_speed)
	removeOutwardVelocity(radial_direction)


func applyRopeConstraints() -> void:
	"""Keeps the moved player within rope length and angle limits."""

	enforceRopeLength()
	enforceAngleCap()


func removeOutwardVelocity(radial_direction: Vector2) -> void:
	"""Removes velocity that would stretch the rope away from the anchor."""

	var outward_speed := player.velocity.dot(radial_direction)
	if outward_speed > 0.0:
		player.velocity -= radial_direction * outward_speed


func enforceRopeLength() -> void:
	"""Keeps the player on the grapple rope radius."""

	var from_anchor := player.global_position - anchor_position
	var distance := from_anchor.length()
	if distance <= 0.0:
		return

	var radial_direction := from_anchor.normalized()
	movePlayerAlongRope(radial_direction * (rope_length - distance))
	removeOutwardVelocity(radial_direction)


func enforceAngleCap() -> void:
	"""Keeps the player inside angle limits without deleting all momentum."""

	var from_anchor := player.global_position - anchor_position
	var distance := from_anchor.length()
	if distance <= 0.0:
		return

	var center_direction := Vector2.DOWN
	var radial_direction := from_anchor.normalized()
	var angle_from_center := center_direction.angle_to(radial_direction)
	var clamped_angle := clampf(
		angle_from_center,
		-deg_to_rad(right_angle_cap_degrees),
		deg_to_rad(left_angle_cap_degrees)
	)
	if is_equal_approx(angle_from_center, clamped_angle):
		return

	var capped_direction := center_direction.rotated(clamped_angle)
	var capped_position := anchor_position + capped_direction * distance
	movePlayerAlongRope(capped_position - player.global_position)
	reboundAtAngleLimit(capped_direction, clamped_angle)


func reboundAtAngleLimit(
	radial_direction: Vector2,
	clamped_angle: float
) -> void:
	"""Reflects part of outward tangential momentum back into the swing."""

	var tangent_direction := Vector2(
		-radial_direction.y,
		radial_direction.x
	)
	var tangent_speed := player.velocity.dot(tangent_direction)
	var pushing_past_left := clamped_angle > 0.0 and tangent_speed > 0.0
	var pushing_past_right := clamped_angle < 0.0 and tangent_speed < 0.0
	if pushing_past_left or pushing_past_right:
		player.velocity -= (
			tangent_direction
			* tangent_speed
			* (1.0 + angle_rebound_factor)
		)


func movePlayerAlongRope(motion: Vector2) -> void:
	"""Moves rope corrections through collision checks."""

	if motion.is_zero_approx():
		return

	player.move_and_collide(motion)


func updateHookLine() -> void:
	"""Draws the hook line while aiming or actively swinging."""

	if hook_line == null or player == null:
		return

	var is_aiming := Input.is_action_pressed(hook_action)
	var should_draw_aim := false
	if is_aiming and not is_hooked:
		should_draw_aim = canStartHook()

	hook_line.visible = should_draw_aim or is_hooked
	if not hook_line.visible:
		return

	if is_hooked and is_instance_valid(active_hook_point):
		anchor_position = active_hook_point.global_position

	hook_line.clear_points()
	hook_line.add_point(player.global_position)
	hook_line.add_point(
		anchor_position
		if is_hooked
		else selected_hook_point.global_position
	)
