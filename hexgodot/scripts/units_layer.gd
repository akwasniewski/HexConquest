extends Node2D

const UNIT_RANGE = 5

var units_at_pos := {}

@onready var unit_scene = preload("res://scenes/unit_display.tscn")
@onready var tile_map = get_node("../TileMapLayer")
@onready var player_influence = get_node("../PlayerInfluence")


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


func add_unit_at(player_id:int, tile_pos: Vector2i, count: int):
	var dest_unit = get_unit_at(tile_pos)
	if dest_unit == null:
		var unit = unit_scene.instantiate()
		unit.set_position(tile_map.map_to_local(tile_pos))
		unit.set_player_id(player_id)
		add_child(unit)
		unit.set_count(count)
		units_at_pos[tile_pos] = unit
		
		player_influence.report_unit_placed(tile_pos, player_id)

	else:
		dest_unit.add_count(count)

func move_unit(source: Vector2i, dest: Vector2i):
	
	if source == dest:
		return
	

	
	var source_unit = get_unit_at(source)
	var dest_unit = get_unit_at(dest)
	
	
	if dest_unit == null:
		var unit = get_unit_at(source)
		units_at_pos.erase(tile_map.local_to_map(unit.get_position()))
		unit.set_position(tile_map.map_to_local(dest))
		units_at_pos[dest] = unit
	else:
		if source_unit.get_player_id() == dest_unit.get_player_id():
			dest_unit.add_count_from(source_unit)
			remove_unit(source_unit)
		else:
			if source_unit.get_count() == dest_unit.get_count():
				remove_unit(source_unit)
				remove_unit(dest_unit)
			else:
				if source_unit.get_count() > dest_unit.get_count():
					source_unit.add_count(-dest_unit.get_count())
					remove_unit(dest_unit)
					source_unit.set_position(tile_map.map_to_local(dest))
					units_at_pos[dest] = source_unit
				else:
					dest_unit.add_count(-source_unit.get_count())
					remove_unit(source_unit)
	
	var unit = get_unit_at(dest)
	if unit != null:
		player_influence.report_unit_placed(dest, unit.get_player_id())
