class_name NpcIdleState
extends State

"""Keeps an NPC stationary while retaining normal gravity."""

var npc: NpcController


func setup(machine: StateMachine, controlled_actor: Node) -> void:
	"""Stores the NPC controlled by this idle state."""

	super.setup(machine, controlled_actor)
	npc = controlled_actor as NpcController


func physicsUpdate(delta: float) -> void:
	"""Stops horizontal movement and applies gravity."""

	npc.velocity.x = move_toward(npc.velocity.x, 0.0, 1200.0 * delta)
	npc.applyGravity(delta)
