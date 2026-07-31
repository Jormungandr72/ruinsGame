class_name PlayerController
extends CharacterBody2D

"""State-driven 2D platformer character controller for the player."""

@export_group("Horizontal Movement")
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var air_control: float = 900.0
@export var air_deceleration: float = 120.0
@export var max_walk_speed: float = 150

@export_group("Jumping")
@export var jump_velocity: float = -400.0
@export var variable_jump_height: float = 0.5
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12
@export var double_jump_count: int = 0

@export_group("Gravity")
@export var gravity: float = 1200.0
@export var fall_gravity_multiplier: float = 1.6
@export var low_jump_gravity_multiplier: float = 2.2
@export var max_fall_speed: float = 700.0

@export_group("Slopes")
@export var max_floor_angle_degrees: float = 50.0
@export var floor_snap_distance: float = 8.0
@export var constant_speed_on_slopes: bool = true
@export var stop_on_slopes: bool = true
@export var collision_safe_margin: float = 0.08
@export var downhill_speed_multiplier: float = 1.3

@export_group("Surfaces")
@export var ice_friction: float = 0.0

@export_group("Input")
@export var hook_action: StringName = &"hook"

@onready var state_machine: StateMachine = $StateMachine
@onready var hook_controller: HookController = $HookController

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var remaining_double_jumps: int = 0
var input_direction: float = 0.0
var facing_direction: float = 1.0
var is_on_ice: bool = false
var hearts_list : Array[TextureRect]
var health = 3

func _ready() -> void:
	"""Configures the character body and starts its state machine."""

	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_max_angle = deg_to_rad(max_floor_angle_degrees)
	floor_snap_length = floor_snap_distance
	floor_constant_speed = constant_speed_on_slopes
	floor_stop_on_slope = stop_on_slopes
	safe_margin = collision_safe_margin
	state_machine.initialize(self)
	

	
	var hearts_parent = $"Health bar/HBoxContainer"
	for child in hearts_parent.get_children():
		hearts_list.append(child)

func take_damage():
	if health > 0:
		health -= 1
		update_heart_display()


func update_heart_display():
	for i in range(hearts_list.size()):
		hearts_list[i].visible = i < health




func _process(delta: float) -> void:
	"""Updates non-physics behaviour and hook visuals."""
	state_machine.update(delta)
	if Input.is_action_just_pressed("Take_damage"):
		take_damage()

	  


func _unhandled_input(event: InputEvent) -> void:
	"""Forwards unhandled input to the active player state."""

	state_machine.handleInput(event)


func _physics_process(delta: float) -> void:
	"""Updates one active state and moves the player exactly once."""

	input_direction = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(input_direction):
		facing_direction = signf(input_direction)

	updateTimers(delta)
	state_machine.physicsUpdate(delta)
	move_and_slide()
	state_machine.afterPhysics(delta)


func updateTimers(delta: float) -> void:
	"""Updates timers shared across player state boundaries."""

	if is_on_floor():
		coyote_timer = coyote_time
		remaining_double_jumps = double_jump_count
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

func canPerformJump() -> bool:
	"""Returns true when a buffered ground, coyote, or double jump is valid."""

	if jump_buffer_timer <= 0.0:
		return false

	return coyote_timer > 0.0 or remaining_double_jumps > 0


func performJump() -> void:
	"""Consumes an available jump and applies its vertical velocity."""

	if coyote_timer <= 0.0:
		remaining_double_jumps -= 1

	velocity.y = jump_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0


func applyHorizontalMovement(delta: float) -> void:
	"""Applies walking, air control, deceleration, and ice friction."""

	if not is_zero_approx(input_direction):
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


func getDownhillSpeedMultiplier(direction: float) -> float:
	"""Returns a slope-scaled speed boost only while walking downhill."""

	if not is_on_floor() or is_zero_approx(direction):
		return 1.0

	var floor_normal := get_floor_normal()
	var floor_tangent := Vector2(-floor_normal.y, floor_normal.x).normalized()
	var movement_tangent := floor_tangent * signf(direction)
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


func applyVariableJumpHeight() -> void:
	"""Shortens the active jump when its input is released."""

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= variable_jump_height


func applyGravity(delta: float) -> void:
	"""Applies rising, falling, and low-jump gravity."""

	if is_on_floor():
		return

	var gravity_force := gravity
	if velocity.y > 0.0:
		gravity_force *= fall_gravity_multiplier
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		gravity_force *= low_jump_gravity_multiplier

	velocity.y = minf(velocity.y + gravity_force * delta, max_fall_speed)
