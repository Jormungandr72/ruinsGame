class_name NpcController
extends CharacterBody2D

"""Base state-driven controller shared by NPC characters."""

@export var gravity: float = 1200.0
@export var max_fall_speed: float = 700.0

@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	"""Initializes the NPC state machine."""

	state_machine.initialize(self)


func _process(delta: float) -> void:
	"""Updates the NPC's active non-physics behaviour."""

	state_machine.update(delta)


func _physics_process(delta: float) -> void:
	"""Updates one NPC state and moves the body once."""

	state_machine.physicsUpdate(delta)
	move_and_slide()
	state_machine.afterPhysics(delta)


func applyGravity(delta: float) -> void:
	"""Applies gravity while the NPC is airborne."""

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
