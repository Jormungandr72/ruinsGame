class_name PlayerState
extends State

"""Base state with typed access to the player controller."""

var player: PlayerController


func setup(machine: StateMachine, controlled_actor: Node) -> void:
	"""Stores the player used by concrete movement states."""

	super.setup(machine, controlled_actor)
	player = controlled_actor as PlayerController


func tryStartAbilityState() -> bool:
	"""Starts grappling when the hook is pressed and a target is available."""

	if Input.is_action_just_pressed(player.hook_action) and player.hook_controller.canStartHook():
		state_machine.changeState(&"Grapple")
		return true

	return false


func changeToGroundState() -> void:
	"""Selects idle or run from the current horizontal input."""

	var destination := &"Idle" if is_zero_approx(player.input_direction) else &"Run"
	state_machine.changeState(destination)
