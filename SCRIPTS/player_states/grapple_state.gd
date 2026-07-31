class_name PlayerGrappleState
extends PlayerState

"""Handles grappling as an exclusive player movement state."""


func enter(_previous_state: State, _data: Dictionary = {}) -> void:
	"""Attaches the hook to the currently valid target."""

	if not player.hook_controller.startHook():
		state_machine.changeState(&"Fall")


func physicsUpdate(delta: float) -> void:
	"""Applies swing forces until the hook button is released."""

	# Jump is intentionally ignored while grappling. Releasing the hook is the
	# only player-controlled way to leave this state. Clearing the buffer also
	# prevents a jump pressed on the rope from firing immediately after release.
	player.jump_buffer_timer = 0.0
	if not Input.is_action_pressed(player.hook_action):
		state_machine.changeState(&"Fall")
		return

	if not player.hook_controller.hasClearActiveHookPath():
		state_machine.changeState(&"Fall")
		return

	player.hook_controller.applySwingForces(delta, player.input_direction)


func afterPhysics(_delta: float) -> void:
	"""Constrains the player to the rope after collision movement."""

	player.hook_controller.applyRopeConstraints()


func exit(_next_state: State) -> void:
	"""Releases the rope while preserving current swing momentum."""

	player.hook_controller.releaseHook()
