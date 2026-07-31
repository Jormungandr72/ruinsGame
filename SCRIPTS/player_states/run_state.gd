class_name PlayerRunState
extends PlayerState

"""Handles grounded player movement."""


func physicsUpdate(delta: float) -> void:
	"""Moves on the ground and checks movement transitions."""

	if tryStartAbilityState():
		return

	if player.canPerformJump():
		player.performJump()
		state_machine.changeState(&"Jump")
		return

	if not player.is_on_floor():
		state_machine.changeState(&"Fall")
		return

	if is_zero_approx(player.input_direction):
		state_machine.changeState(&"Idle")
		return

	player.applyHorizontalMovement(delta)
	player.alignVelocityToFloor()
