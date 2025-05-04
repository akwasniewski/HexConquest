extends Node2D

const UNIT_RANGE = 5

var units_at_pos := {}

@onready var unit_scene = preload("res://scenes/unit_display.tscn")
@onready var tile_map = get_node("../TileMapLayer")


func add_unit_at(player_id:int, unit_id: int, tile_pos: Vector2i, count: int):
	print("player added")
	var unit = unit_scene.instantiate()
	unit.set_position(tile_map.map_to_local(tile_pos))
	unit.set_player_id(player_id)
	unit.set_id(unit_id)
	add_child(unit)
	unit.set_count(count)
	units_at_pos[tile_pos] = unit

func get_unit_at(tile_pos: Vector2i) -> Node2D:
	return units_at_pos.get(tile_pos, null)

func get_unit(uid: int) -> Node2D:
	for unit in units_at_pos.values():
		if unit.unit_id==uid:
			return unit
	return null

func remove_unit(unit):
	var tile_pos = tile_map.local_to_map(unit.get_position())
	units_at_pos.erase(tile_pos)
	unit.queue_free()
		
#func remove_unit_at(tile_pos: Vector2i):
	#var unit = units_at_pos.get(tile_pos)
	#if unit:
		#remove_unit(unit)

func pos_to_axial(pos: Vector2i) -> Vector2i:
	var x = pos.x - (pos.y - (pos.x&1)) / 2
	var y = pos.y
	return Vector2i(x, y)

func axial_to_pos(hex: Vector2i):
	var x = hex.x + (hex.y - (hex.y&1)) / 2
	var y = hex.y
	return Vector2i(x, y)

func hex_dist(lhs: Vector2i, rhs: Vector2i):
	var lhs_axial = pos_to_axial(lhs)
	var rhs_axial = pos_to_axial(rhs)
	return (abs(lhs_axial.x - rhs_axial.x) 
		  + abs(lhs_axial.x + lhs_axial.y - rhs_axial.x - rhs_axial.y)
		  + abs(lhs_axial.y - rhs_axial.y)) / 2

func can_move_unit(unit, dest: Vector2i):
	var source = tile_map.local_to_map(unit.get_position())
	
	var source_is_on_map = true #TODO
	var dest_is_on_map = true #TODO
	var dist_ok = hex_dist(source, dest) <= UNIT_RANGE
	return (source_is_on_map and dest_is_on_map and dist_ok)
func move_unit(unit_id: int, dest: Vector2i):
	var unit = get_unit(unit_id)
	units_at_pos.erase(tile_map.local_to_map(unit.get_position()))
	unit.set_position(tile_map.map_to_local(dest))
	units_at_pos[dest] = unit
