extends Node2D

var units_at_pos := {}

@onready var unit_scene = preload("res://scenes/unit_display.tscn")
@onready var tile_map = get_node("../TileMapLayer")


func add_unit_at(tile_pos: Vector2i, count: int):
	var unit = unit_scene.instantiate()
	unit.position = tile_map.map_to_local(tile_pos)
	add_child(unit)
	unit.set_count(count)
	units_at_pos[tile_pos] = unit

func get_unit_at(tile_pos: Vector2i) -> Node2D:
	return units_at_pos.get(tile_pos, null)

func remove_unit_at(tile_pos: Vector2i):
	var unit = units_at_pos.get(tile_pos)
	if unit:
		unit.queue_free()
		units_at_pos.erase(tile_pos)
