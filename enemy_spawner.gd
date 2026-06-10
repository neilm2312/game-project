extends Node
class_name EnemySpawner

@export var entities: Node2D
@export var enemy_scenes: Array[PackedScene]  # drag any enemy scenes in here

var _types: Array = []
var _spawned: Dictionary = {}

func _ready() -> void:
	for scene in enemy_scenes:
		register(scene)

func register(scene: PackedScene, weight: float = 1.0,
		wander: Dictionary = {}, config: Dictionary = {}) -> void:
	_types.append({
		"scene": scene,
		"weight": weight,
		"wander": wander,
		"config": config,
	})

func on_chunk_generated(chunk: Vector2i, floor_tiles: Array,
		safe_radius: int, enemies_min: int, enemies_max: int) -> void:
	if _types.is_empty() or _spawned.has(chunk):
		return
	_spawned[chunk] = true
	var valid := floor_tiles.filter(func(t) -> bool:
		return abs(t.x) > safe_radius or abs(t.y) > safe_radius
	)
	if valid.is_empty():
		return
	valid.shuffle()
	var count := randi_range(enemies_min, enemies_max)
	for i in mini(count, valid.size()):
		_place(_pick_type(), valid[i])

func _pick_type() -> Dictionary:
	var total := 0.0
	for entry in _types:
		total += entry.weight
	var r := randf() * total
	for entry in _types:
		r -= entry.weight
		if r <= 0.0:
			return entry
	return _types[-1]

func _place(entry: Dictionary, tile: Vector2i) -> void:
	var e: Node2D = entry.scene.instantiate()
	entities.add_child(e)
	e.global_position = (Vector2(tile) + Vector2(0.5, 0.5)) * WorldManager.TILE_SIZE
	if e.has_method("init_wander"):
		e.init_wander(entry.wander)
	if e.has_method("init"):
		e.init(entry.config)
