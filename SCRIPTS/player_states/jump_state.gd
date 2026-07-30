class_name PlayerJumpState
extends PlayerState

"""Handles the upward part of player movement."""


func physicsUpdate(delta: float) -> void:
	"""Applies air control, jump shortening, and gravity."""

	if tryStartAbilityState():
		return

	player.applyHorizontalMovement(delta)
	player.applyVariableJumpHeight()
	player.applyGravity(delta)

	if player.velocity.y >= 0.0:
		state_machine.changeState(&"Fall")


func afterPhysics(_delta: float) -> void:
	"""Returns to a grounded state after an early landing."""

	if player.is_on_floor():
		changeToGroundState()
