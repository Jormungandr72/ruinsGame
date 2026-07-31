class_name BreakableTileMap
extends TileMapLayer

"""Adds independent directional break stages to every occupied map cell."""

const INVALID_CELL: Vector2i = Vector2i(2147483647, 2147483647)
const EIGHT_NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

signal cell_break_hit(cell: Vector2i, stage: BreakStage, hits_in_stage: int)
signal cell_break_stage_changed(cell: Vector2i, stage: BreakStage)
signal cell_broken(cell: Vector2i)

enum BreakDirection {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const SOURCE_BREAK_DOWN: int = 0
const SOURCE_BREAK_UP: int = 1
const SOURCE_BREAK_LEFT: int = 2
const SOURCE_BREAK_RIGHT: int = 3

enum BreakStage {
	INTACT,
	YELLOW,
	RED,
	BROKEN,
}

@export_range(1.0, 512.0, 1.0, "or_greater") var break_range: float = 64
@export_range(0.0, 89.0, 1.0) var angle_tolerance_degrees: float = 35.0
@export_range(1, 10, 1) var hits_per_stage: int = 1

const BREAK_ACTION: StringName = &"break_tile"
const PLAYER_GROUP: StringName = &"player"
const YELLOW_STAGE_COLOR: Color = Color.YELLOW
const RED_STAGE_COLOR: Color = Color.RED
const STAGE_BOX_SCALE: float = 1.0
const STAGE_BOX_Z_INDEX: int = 10

var player: Node2D
var cell_stages: Dictionary = {}
var cell_hits: Dictionary = {}
var stage_boxes: Dictionary = {}


func _ready() -> void:
	"""Finds the player used for range and directional checks."""

	findPlayer()


func _process(_delta: float) -> void:
	"""Damages the nearest eligible occupied cell when break is pressed."""

	if not Input.is_action_just_pressed(BREAK_ACTION):
		return

	if player == null or not is_instance_valid(player):
		findPlayer()

	var target_cell := findNearestBreakableCell()
	if target_cell != INVALID_CELL:
		applyBreakHitToConnectedRegion(target_cell)


func findPlayer() -> void:
	"""Finds a player from an optional path or configurable group."""

	player = null
	player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D


func findNearestBreakableCell() -> Vector2i:
	"""Returns the nearest occupied cell valid for range and direction."""

	if player == null:
		return INVALID_CELL

	var nearest_cell := INVALID_CELL
	var nearest_distance := INF
	for cell in get_used_cells():
		var cell_position := to_global(map_to_local(cell))
		var player_offset := player.global_position - cell_position
		var distance := player_offset.length()
		if (
			player_offset.is_zero_approx()
			or distance > break_range
			or distance >= nearest_distance
		):
			continue

		var cell_direction := getCellBreakDirection(cell)
		if not isPlayerAtBreakAngle(player_offset, cell_direction):
			continue

		nearest_cell = cell
		nearest_distance = distance

	return nearest_cell


func isPlayerAtBreakAngle(
	player_offset: Vector2,
	cell_direction: BreakDirection
) -> bool:
	"""Returns true when an offset lies on the configured breaking side."""

	var required_direction := getRequiredDirection(cell_direction)
	var angle_to_player := absf(
		required_direction.angle_to(player_offset.normalized())
	)
	return angle_to_player <= deg_to_rad(angle_tolerance_degrees)


func getRequiredDirection(cell_direction: BreakDirection) -> Vector2:
	"""Returns the world direction required by one painted cell."""

	var required_direction := Vector2.UP
	match cell_direction:
		BreakDirection.DOWN:
			required_direction = Vector2.DOWN
		BreakDirection.RIGHT:
			required_direction = Vector2.RIGHT
		BreakDirection.LEFT:
			required_direction = Vector2.LEFT

	return required_direction


func getCellBreakDirection(cell: Vector2i) -> BreakDirection:
	"""Returns break direction from the atlas source painted at a cell."""

	match get_cell_source_id(cell):
		SOURCE_BREAK_DOWN:
			return BreakDirection.DOWN
		SOURCE_BREAK_LEFT:
			return BreakDirection.LEFT
		SOURCE_BREAK_RIGHT:
			return BreakDirection.RIGHT
		_:
			# Source 1 is Up. Unknown sources also safely default to Up.
			return BreakDirection.UP


func applyBreakHit(cell: Vector2i) -> void:
	"""Applies one hit to a cell and advances its independent stage."""

	if get_cell_source_id(cell) == -1:
		return

	var current_stage: int = cell_stages.get(cell, BreakStage.INTACT)
	var hits_in_stage: int = cell_hits.get(cell, 0) + 1
	cell_hits[cell] = hits_in_stage
	cell_break_hit.emit(cell, current_stage, hits_in_stage)
	if hits_in_stage < hits_per_stage:
		return

	cell_hits[cell] = 0
	current_stage += 1
	cell_stages[cell] = current_stage
	cell_break_stage_changed.emit(cell, current_stage)

	match current_stage:
		BreakStage.YELLOW:
			setStageBox(cell, YELLOW_STAGE_COLOR)
		BreakStage.RED:
			setStageBox(cell, RED_STAGE_COLOR)
		BreakStage.BROKEN:
			breakCell(cell)


func applyBreakHitToConnectedRegion(starting_cell: Vector2i) -> void:
	"""Hits every eight-way connected breakable, regardless of direction."""

	for cell in findConnectedCells(starting_cell):
		applyBreakHit(cell)


func findConnectedCells(starting_cell: Vector2i) -> Array[Vector2i]:
	"""Flood-fills breakables of every direction connected in eight ways."""

	var connected_cells: Array[Vector2i] = []
	if get_cell_source_id(starting_cell) == -1:
		return connected_cells

	var pending_cells: Array[Vector2i] = [starting_cell]
	var visited_cells: Dictionary = {starting_cell: true}

	while not pending_cells.is_empty():
		var current_cell: Vector2i = pending_cells.pop_back()
		connected_cells.append(current_cell)

		for neighbour_offset in EIGHT_NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current_cell + neighbour_offset
			if visited_cells.has(neighbour):
				continue

			visited_cells[neighbour] = true
			if get_cell_source_id(neighbour) != -1:
				pending_cells.append(neighbour)

	return connected_cells


func setStageBox(cell: Vector2i, color: Color) -> void:
	"""Creates or recolors the placeholder damage box over one cell."""

	var stage_box := stage_boxes.get(cell) as Polygon2D
	if stage_box == null:
		stage_box = Polygon2D.new()
		stage_box.position = map_to_local(cell)
		stage_box.z_index = STAGE_BOX_Z_INDEX

		var half_size := Vector2(tile_set.tile_size) * 0.5 * STAGE_BOX_SCALE
		stage_box.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])
		add_child(stage_box)
		stage_boxes[cell] = stage_box

	stage_box.color = color


func breakCell(cell: Vector2i) -> void:
	"""Erases one cell, including its generated collision, at final stage."""

	erase_cell(cell)
	var stage_box := stage_boxes.get(cell) as Polygon2D
	if stage_box != null:
		stage_box.queue_free()

	stage_boxes.erase(cell)
	cell_hits.erase(cell)
	cell_stages.erase(cell)
	cell_broken.emit(cell)
