class_name MyTileData

extends Resource  # albo Object, jeśli nie będziesz tego zapisywać do pliku

var position: Vector2i
var is_city: bool
var is_port: bool
var is_water: bool
var owner: int

func _init(_position, _is_city: bool = false, _is_port: bool = false, _is_water: bool = false, _owner: int = -1):
	position = _position
	is_city = _is_city
	is_port = _is_port
	is_water = _is_water
	owner = _owner
	
# Metody do aktualizacji pól
func set_city(value: bool) -> void:
	is_city = value

func set_port(value: bool) -> void:
	is_port = value

func set_water(value: bool) -> void:
	is_water = value

func set_owner(value: int) -> void:
	owner = value
	
	
func get_neighbors(map_size: Vector2i) -> Array[Vector2i]:
	if position[0]%2 != 0 :
		var res = [
			position + Vector2i(-1,-1),
			position + Vector2i(0,-1),
			position + Vector2i(1,0),
			position + Vector2i(0,1),
			position + Vector2i(-1,1),
			position + Vector2i(-1,0)
		]
		var new_res:Array[Vector2i]
		for r in res:
			if abs(r.x) < abs(map_size.x) and abs(r.y) < abs(map_size.y):
				new_res.append(r);
		return new_res
	else:
		var res = [
			position + Vector2i(0,-1),
			position + Vector2i(1,-1),
			position + Vector2i(1,0),
			position + Vector2i(1,1),
			position + Vector2i(0,1),
			position + Vector2i(-1,0)
		]
		var new_res:Array[Vector2i]
		for r in res:
			if abs(r.x) < abs(map_size.x) and abs(r.y) < abs(map_size.y):
				new_res.append(r);
		return new_res
