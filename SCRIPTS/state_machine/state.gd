class_name State
extends Node

"""Base lifecycle used by player and NPC states."""

var state_machine: StateMachine
var actor: Node


func setup(machine: StateMachine, controlled_actor: Node) -> void:
	"""Connects the state to its machine and controlled actor."""

	state_machine = machine
	actor = controlled_actor


func enter(_previous_state: State, _data: Dictionary = {}) -> void:
	"""Runs when this state becomes active."""

	pass


func exit(_next_state: State) -> void:
	"""Runs immediately before another state becomes active."""

	pass


func handleInput(_event: InputEvent) -> void:
	"""Handles input forwarded by the state machine."""

	pass


func update(_delta: float) -> void:
	"""Updates non-physics state behaviour."""

	pass


func physicsUpdate(_delta: float) -> void:
	"""Updates state behaviour before the actor moves."""

	pass


func afterPhysics(_delta: float) -> void:
	"""Updates state behaviour after the actor moves."""

	pass
