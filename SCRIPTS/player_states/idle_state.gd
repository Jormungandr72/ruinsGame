class_name PlayerIdleState
extends PlayerState

"""Handles the stationary grounded player state."""


func physicsUpdate(delta: float) -> void:
	"""Checks grounded transitions and applies standing friction."""

	if tryStartAbilityState():
		return

	if player.canPerformJump():
		player.performJump()
		state_machine.changeState(&"Jump")
		return

	if not player.is_on_floor():
		state_machine.changeState(&"Fall")
		return

	if not is_zero_approx(player.input_direction):
		state_machine.changeState(&"Run")
		return

	player.applyHorizontalMovement(delta)
	player.alignVelocityToFloor()
