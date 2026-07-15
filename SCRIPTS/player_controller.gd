class_name PlayerController
extends CharacterBody2D

"""Reusable 2D platformer character controller for the player."""

@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var air_control: float = 900.0
@export var air_deceleration: float = 120.0
@export var max_walk_speed: float = 220.0
# Physics

@export var jump_velocity: float = -420.0
@export var variable_jump_height: float = 0.5
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12
@export var double_jump_count: int = 0
# Jumping

@export var gravity: float = 1200.0
@export var fall_gravity_multiplier: float = 1.6
@export var low_jump_gravity_multiplier: float = 2.2
@export var max_fall_speed: float = 700.0
# Gravity

@export var max_floor_angle_degrees: float = 50.0
# The steepest surface treated as floor. Anything steeper is treated like a wall.
@export var floor_snap_distance: float = 8.0
# How far downward the character searches for the floor. Increasing it helps the player stay attached when walking downhill
@export var constant_speed_on_slopes: bool = true
@export var stop_on_slopes: bool = true
@export var collision_safe_margin: float = 0.08
# A small buffer used when detecting collisions. Increasing it can reduce jitter but if too big will make the character float
@export var downhill_speed_multiplier: float = 1.7
# Slopes

@export var dash_speed: float = 520.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.45
# Dash

@export var ice_friction: float = 0.0
# Ice

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var remaining_double_jumps: int = 0


var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0

var is_on_ice: bool = false
var is_dashing: bool = false


func _ready() -> void:
	"""Configures grounded motion for traversal across tile slopes."""

	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_max_angle = deg_to_rad(max_floor_angle_degrees)
	floor_snap_length = floor_snap_distance
	floor_constant_speed = constant_speed_on_slopes
	floor_stop_on_slope = stop_on_slopes
	safe_margin = collision_safe_margin


func _physics_process(delta: float) -> void:
	"""Updates player movement every physics frame."""

	var input_direction := Input.get_axis("move_left", "move_right")

	handleTimers(delta)
	handleDash(input_direction, delta)

	if not is_dashing:
		handleHorizontalMovement(input_direction, delta)
		alignVelocityToFloor()
		handleJumping(delta)
		handleGravity(delta)
		
	move_and_slide()


func handleTimers(delta: float) -> void:
	"""Updates coyote time, jump buffer, and dash cooldown timers."""

	if is_on_floor():
		coyote_timer = coyote_time
		remaining_double_jumps = double_jump_count
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
	else:
		jump_buffer_timer -= delta

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta


func handleHorizontalMovement(input_direction: float, delta: float) -> void:
	"""Handles walking, air control, deceleration, and ice friction."""

	if input_direction != 0.0:
		var control := acceleration if is_on_floor() else air_control
		var target_speed := (
			input_direction
			* max_walk_speed
			* getDownhillSpeedMultiplier(input_direction)
		)
		var keeping_air_momentum := (
			not is_on_floor()
			and absf(velocity.x) > max_walk_speed
			and signf(velocity.x) == signf(input_direction)
		)

		if not keeping_air_momentum:
			velocity.x = move_toward(velocity.x, target_speed, control * delta)
	else:
		var friction := air_deceleration
		if is_on_floor():
			friction = ice_friction if is_on_ice else deceleration

		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func getDownhillSpeedMultiplier(input_direction: float) -> float:
	"""Returns a slope-scaled speed boost only while walking downhill."""

	if not is_on_floor() or is_zero_approx(input_direction):
		return 1.0

	var floor_normal := get_floor_normal()
	var floor_tangent := Vector2(-floor_normal.y, floor_normal.x).normalized()
	var movement_tangent := floor_tangent * signf(input_direction)

	if movement_tangent.y <= 0.0:
		return 1.0

	var maximum_slope_vertical := maxf(
		sin(deg_to_rad(max_floor_angle_degrees)),
		0.001
	)
	var slope_strength := clampf(
		movement_tangent.y / maximum_slope_vertical,
		0.0,
		1.0
	)
	return lerpf(1.0, downhill_speed_multiplier, slope_strength)


func alignVelocityToFloor() -> void:
	"""Aligns walking velocity to the floor while preserving horizontal speed."""

	if not is_on_floor() or is_zero_approx(velocity.x):
		return

	var floor_normal := get_floor_normal()
	var floor_tangent := Vector2(-floor_normal.y, floor_normal.x).normalized()

	if is_zero_approx(floor_tangent.x):
		return

	velocity.y = velocity.x * floor_tangent.y / floor_tangent.x


func handleJumping(_delta: float) -> void:
	"""Handles normal jumps, coyote jumps, buffered jumps, and double jumps."""

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			performJump()
		elif remaining_double_jumps > 0:
			remaining_double_jumps -= 1
			performJump()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= variable_jump_height


func performJump() -> void:
	"""Makes the player jump."""

	velocity.y = jump_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0


func handleGravity(delta: float) -> void:
	"""Applies gravity, fall gravity, low jump gravity, and max fall speed."""

	if is_on_floor():
		return

	var gravity_force := gravity

	if velocity.y > 0.0:
		gravity_force *= fall_gravity_multiplier
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		gravity_force *= low_jump_gravity_multiplier

	velocity.y = min(velocity.y + gravity_force * delta, max_fall_speed)


func handleDash(input_direction: float, delta: float) -> void:
	"""Handles dash movement, dash duration, and dash cooldown."""

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown

		if input_direction != 0.0:
			dash_direction = input_direction

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0

		if dash_timer <= 0.0:
			is_dashing = false
