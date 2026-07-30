class_name PlayerFallState
extends PlayerState

"""Handles descending and general airborne player movement."""


func physicsUpdate(delta: float) -> void:
	"""Applies air movement, buffered jumps, and gravity."""

	if tryStartAbilityState():
		return

	if player.canPerformJump():
		player.performJump()
		state_machine.changeState(&"Jump")
		return

	player.applyHorizontalMovement(delta)
	player.applyGravity(delta)


func afterPhysics(_delta: float) -> void:
	"""Selects a grounded state after landing."""

	if player.is_on_floor():
		changeToGroundState()
