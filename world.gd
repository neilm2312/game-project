extends Node2D
class_name WorldManager

# --- Constants ---
const TILE_SIZE  := 16
const CHUNK_SIZE := 16

# --- Tile settings ---
const FLOOR_SRC  := 0
const WALL_SRC   := 1
const FLOOR_TILE := Vector2i(0, 0)
const WALL_TILE  := Vector2i(0, 0)

# --- World ---
@export_group("World")
@export var safe_radius: int = 5
@export var render_distance: int = 2

# --- Generation ---
@export_group("Generation")
@export var noise_frequency: float = 0.1
@export var wall_threshold: float = 0.0
@export var birth_limit: int = 5
@export var survival_limit: int = 4

# --- Spawning ---
@export_group("Spawning")
@export var enemies_min: int = 0
@export var enemies_max: int = 2

# --- Scenes ---
@export_group("Scenes")
@export var player_scene: PackedScene

@onready var tilemap: TileMap    = $TileMap
@onready var entities: Node2D    = $Entities
@onready var spawner: EnemySpawner = $EnemySpawner

var noise          := FastNoiseLite.new()
var loaded_chunks  := {}
var player_ref:    Node2D = null
var last_chunk     := Vector2i(999, 999)

func _ready() -> void:
	noise.seed = randi()
	noise.frequency = noise_frequency
	last_chunk = Vector2i(0, 0)
	_update_chunks()
	_spawn_player()

func _process(_delta) -> void:
	if player_ref == null:
		return
	var current := _world_to_chunk(player_ref.global_position)
	if current != last_chunk:
		last_chunk = current
		_update_chunks()

func _world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(pos.x / (CHUNK_SIZE * TILE_SIZE)),
		floori(pos.y / (CHUNK_SIZE * TILE_SIZE))
	)

func _update_chunks() -> void:
	for cy in range(last_chunk.y - render_distance, last_chunk.y + render_distance + 1):
		for cx in range(last_chunk.x - render_distance, last_chunk.x + render_distance + 1):
			var key := Vector2i(cx, cy)
			if not loaded_chunks.has(key):
				_generate_chunk(key)
				loaded_chunks[key] = true

func _generate_chunk(chunk: Vector2i) -> void:
	var floor_tiles: Array = []
	for ly in CHUNK_SIZE:
		for lx in CHUNK_SIZE:
			var wx := chunk.x * CHUNK_SIZE + lx
			var wy := chunk.y * CHUNK_SIZE + ly
			if _is_wall(wx, wy):
				tilemap.set_cell(0, Vector2i(wx, wy), WALL_SRC, WALL_TILE)
			else:
				tilemap.set_cell(0, Vector2i(wx, wy), FLOOR_SRC, FLOOR_TILE)
				floor_tiles.append(Vector2i(wx, wy))
	spawner.on_chunk_generated(chunk, floor_tiles, safe_radius, enemies_min, enemies_max)

func _is_wall(wx: int, wy: int) -> bool:
	if abs(wx) <= safe_radius and abs(wy) <= safe_radius:
		return false
	var base := noise.get_noise_2d(wx, wy) > wall_threshold
	var neighbors := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if noise.get_noise_2d(wx + dx, wy + dy) > wall_threshold:
				neighbors += 1
	if base:
		return neighbors >= survival_limit
	else:
		return neighbors >= birth_limit

func _spawn_player() -> void:
	if player_scene == null:
		return
	player_ref = player_scene.instantiate()
	add_child(player_ref)
	player_ref.global_position = Vector2.ZERO
