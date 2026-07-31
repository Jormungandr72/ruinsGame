class_name StateMachine
extends Node

"""Runs one child State at a time and coordinates safe transitions."""

signal state_changed(previous_state: StringName, current_state: StringName)

@export var initial_state: NodePath

var current_state: State
var previous_state: State
var actor: Node
var states: Dictionary = {}
var is_updating: bool = false
var queued_state_name: StringName = &""
var queued_state_data: Dictionary = {}


func initialize(controlled_actor: Node) -> void:
	"""Finds child states and enters the configured initial state."""

	actor = controlled_actor
	states.clear()

	for child in get_children():
		var state := child as State
		if state == null:
			continue

		state.setup(self, actor)
		states[StringName(state.name)] = state

	var starting_state := get_node_or_null(initial_state) as State
	if starting_state == null and not states.is_empty():
		starting_state = states.values()[0] as State

	if starting_state == null:
		push_error("StateMachine requires at least one child State.")
		return

	current_state = starting_state
	current_state.enter(null)
	state_changed.emit(&"", StringName(current_state.name))


func changeState(state_name: StringName, data: Dictionary = {}) -> bool:
	"""Changes state now, or queues the change until the current update ends."""

	if not states.has(state_name):
		push_error("Unknown state requested: %s" % state_name)
		return false

	if current_state == states[state_name]:
		return false

	if is_updating:
		queued_state_name = state_name
		queued_state_data = data
		return true

	performTransition(state_name, data)
	return true


func handleInput(event: InputEvent) -> void:
	"""Forwards an input event to the active state."""

	if current_state == null:
		return

	current_state.handleInput(event)
	applyQueuedTransition()


func update(delta: float) -> void:
	"""Forwards a regular frame update to the active state."""

	if current_state == null:
		return

	is_updating = true
	current_state.update(delta)
	is_updating = false
	applyQueuedTransition()


func physicsUpdate(delta: float) -> void:
	"""Forwards the pre-movement physics update to the active state."""

	if current_state == null:
		return

	is_updating = true
	current_state.physicsUpdate(delta)
	is_updating = false
	applyQueuedTransition()


func afterPhysics(delta: float) -> void:
	"""Forwards the post-movement physics update to the active state."""

	if current_state == null:
		return

	is_updating = true
	current_state.afterPhysics(delta)
	is_updating = false
	applyQueuedTransition()


func performTransition(state_name: StringName, data: Dictionary) -> void:
	"""Exits the current state and enters the requested state."""

	var next_state := states[state_name] as State
	var old_state := current_state

	if old_state != null:
		old_state.exit(next_state)

	previous_state = old_state
	current_state = next_state
	current_state.enter(old_state, data)

	var old_name := &""
	if old_state != null:
		old_name = StringName(old_state.name)
	state_changed.emit(old_name, StringName(current_state.name))


func applyQueuedTransition() -> void:
	"""Applies a state transition requested during an update callback."""

	if queued_state_name.is_empty():
		return

	var state_name := queued_state_name
	var data := queued_state_data
	queued_state_name = &""
	queued_state_data = {}
	performTransition(state_name, data)
