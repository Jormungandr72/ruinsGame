class_name HookController
extends Node2D

"""Grapple swing controller that preserves momentum after release."""

@export var player_path: NodePath = NodePath("..")
@export var claw_path: NodePath = NodePath("../../Claw1")
# This will be heavily changed after the grapple hook works as intended, there will be a list of nodes and the hook points will have a more sensible name

@export var hook_action: StringName = "hook"
@export var swing_gravity: float = 1100.0
@export var swing_control: float = 950.0
@export var min_rope_length: float = 24.0
@export var max_rope_length: float = 420.0
@export var left_angle_cap_degrees: float = 75.0
@export var right_angle_cap_degrees: float = 75.0
@export var max_swing_speed: float = 700.0
@export var release_speed_multiplier: float = 1.0
@export var line_width: float = 4.0
@export var line_color: Color = Color.BLACK

var player: CharacterBody2D
var claw: Node2D
var claw_target: Node2D
var hook_line: Line2D
var anchor_position: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var last_swing_velocity: Vector2 = Vector2.ZERO
var is_hooked: bool = false


func _ready() -> void:
	"""Finds required nodes and creates the hook placeholder line."""

	findHookNodes()
	createHookLine()


func _physics_process(delta: float) -> void:
	"""Handles hook input, swing movement, and momentum release."""

	if player == null or claw == null:
		findHookNodes()
		if player == null or claw == null:
			return

	if Input.is_action_just_pressed(hook_action):
		tryStartHook()

	if is_hooked:
		if Input.is_action_pressed(hook_action):
			updateSwing(delta)
		else:
			releaseHook()

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


func findHookNodes() -> void:
	"""Finds the player, Claw1, and Claw1 collision target."""
	# This will be heavily changed after the grapple hook works as intended

	player = get_node_or_null(player_path) as CharacterBody2D
	claw = get_node_or_null(claw_path) as Node2D

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	if player == null:
		player = current_scene.find_child("Player", true, false) as CharacterBody2D

	if claw == null:
		claw = current_scene.find_child("Claw1", true, false) as Node2D

	if claw != null:
		claw_target = claw.find_child("CollisionShape2D", true, false) as Node2D


func tryStartHook() -> void:
	"""Attaches the grapple if the ray can reach Claw1."""

	if not canHookClaw():
		return

	anchor_position = getClawTargetPosition()
	rope_length = player.global_position.distance_to(anchor_position)
	last_swing_velocity = player.velocity
	is_hooked = true
	player.set_physics_process(false)


func canHookClaw() -> bool:
	"""Returns true when the hook ray reaches Claw1 before hitting another body."""

	var target_position := getClawTargetPosition()
	var target_distance := player.global_position.distance_to(target_position)
	
	if target_distance < min_rope_length or target_distance > max_rope_length:
		return false

	return isHookPathClear(target_position)


func isHookPathClear(target_position: Vector2) -> bool:
	"""Returns true when no platform cuts off the hook ray."""

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		player.global_position,
		target_position
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

	return collider == claw or claw.is_ancestor_of(collider)


func updateSwing(delta: float) -> void:
	"""Applies pendulum movement with player-controlled direction changes."""

	if not isHookPathClear(anchor_position):
		releaseHook()
		return

	var from_anchor := player.global_position - anchor_position
	if from_anchor.length() <= 0.0:
		return

	var input_direction := Input.get_axis("move_left", "move_right")
	var radial_direction := from_anchor.normalized()
	var tangent_direction := Vector2(-radial_direction.y, radial_direction.x)
	if tangent_direction.x < 0.0:
		tangent_direction = -tangent_direction

	player.velocity.y += swing_gravity * delta
	player.velocity += tangent_direction * input_direction * swing_control * delta
	player.velocity = player.velocity.limit_length(max_swing_speed)

	removeOutwardVelocity(radial_direction)
	player.move_and_slide()
	enforceRopeLength()
	enforceAngleCap()
	last_swing_velocity = player.velocity


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
	"""Keeps the player inside the left and right swing angle limits."""

	var from_anchor := player.global_position - anchor_position
	var distance := from_anchor.length()
	if distance <= 0.0:
		return

	var center_direction := Vector2(0.0, 1.0)
	var radial_direction := from_anchor.normalized()
	var angle_from_center: float = center_direction.angle_to(radial_direction)
	var left_angle_cap: float = deg_to_rad(left_angle_cap_degrees)
	var right_angle_cap: float = deg_to_rad(right_angle_cap_degrees)
	var clamped_angle: float = clampAngle(
		angle_from_center,
		-right_angle_cap,
		left_angle_cap
	)

	if isAngleEqualApprox(angle_from_center, clamped_angle):
		return

	var capped_direction := center_direction.rotated(clamped_angle)
	var capped_position := anchor_position + capped_direction * distance
	movePlayerAlongRope(capped_position - player.global_position)
	removeAngleLimitVelocity(capped_direction, clamped_angle)


func removeAngleLimitVelocity(radial_direction: Vector2, clamped_angle: float) -> void:
	"""Removes swing velocity that pushes farther past an angle limit."""

	var tangent_direction := Vector2(-radial_direction.y, radial_direction.x)
	var tangent_speed := player.velocity.dot(tangent_direction)
	var at_left_cap := clamped_angle > 0.0 and tangent_speed > 0.0
	var at_right_cap := clamped_angle < 0.0 and tangent_speed < 0.0

	if at_left_cap or at_right_cap:
		player.velocity -= tangent_direction * tangent_speed


func isAngleEqualApprox(first_angle: float, second_angle: float) -> bool:
	"""Returns true when two angle values are close enough to count as equal."""

	return absf(first_angle - second_angle) < 0.001


func clampAngle(angle: float, minimum_angle: float, maximum_angle: float) -> float:
	"""Returns an angle kept between the supplied minimum and maximum."""

	if angle < minimum_angle:
		return minimum_angle

	if angle > maximum_angle:
		return maximum_angle

	return angle


func movePlayerAlongRope(motion: Vector2) -> void:
	"""Moves rope corrections through collision checks so platforms still block."""

	if motion.length() <= 0.0:
		return

	player.move_and_collide(motion)


func releaseHook() -> void:
	"""Releases the grapple while keeping the current swing momentum."""

	if not is_hooked:
		return

	is_hooked = false
	player.velocity = last_swing_velocity * release_speed_multiplier
	player.set_physics_process(true)


func getClawTargetPosition() -> Vector2:
	"""Returns the hook anchor point on Claw1."""

	if claw_target != null:
		return claw_target.global_position

	return claw.global_position


func updateHookLine() -> void:
	"""Draws the black hook line while aiming or swinging."""

	var is_aiming := Input.is_action_pressed(hook_action)
	var should_draw_aim := is_aiming and not is_hooked and canHookClaw()
	hook_line.visible = should_draw_aim or is_hooked
	if not hook_line.visible:
		return

	hook_line.clear_points()
	hook_line.add_point(player.global_position)
	hook_line.add_point(getClawTargetPosition() if not is_hooked else anchor_position)
