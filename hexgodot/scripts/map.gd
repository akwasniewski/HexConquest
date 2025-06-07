extends TileMapLayer

#https://www.redblobgames.com/grids/hexagons
#
#enum TileType {
	#LAND,
	#WATER,
#}
#
#enum CityType {
	#LAND,
	#PORT,
#}
#
#var tiles_at_pos := {}
#var cities_at_pos := {}
#
#
#func set_land(pos: Vector2i):
	#tiles_at_pos[pos] = TileType.LAND
#
#
#func set_water(pos: Vector2i):
	#tiles_at_pos[pos] = TileType.WATER
#
#
#func is_land(pos: Vector2i) -> bool:
	#return (tiles_at_pos[pos] == TileType.LAND)
#
#
#func is_water(pos: Vector2i) -> bool:
	#return (tiles_at_pos[pos] == TileType.WATER)
#
#
#func is_part_of_map(pos: Vector2i) -> bool:
	#return (tiles_at_pos.get(pos) != null)
#
#
#func place_land_city(pos: Vector2i):
	#cities_at_pos[pos] = CityType.LAND
#
#
#func place_port_city(pos: Vector2i):
	#cities_at_pos[pos] = CityType.PORT
#

var axial_direction_vectors = [
	Vector2i(+1, 0), Vector2i(+1, -1), Vector2i(0, -1), 
	Vector2i(-1, 0), Vector2i(-1, +1), Vector2i(0, +1), 
]


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

func hexes_in_range(center_pos: Vector2i, dist: int):
	dist -= 1
	assert(dist >= 0)
	var center_axial = pos_to_axial(center_pos)
	var results = []
	#for each -N ≤ q ≤ +N:
	for q in range(-dist, dist + 1):
		#for each max(-N, -q-N) ≤ r ≤ min(+N, -q+N):
		for r in range(max(-dist, -q-dist), min(+dist, -q+dist) + 1):
			results.append(
				axial_to_pos(center_axial + Vector2i(q, r))
			)
	return results

func neighbours_of(pos: Vector2i):
	var axial = pos_to_axial(pos)
	var result = []
	for v in axial_direction_vectors:
		result.append(axial_to_pos(axial + v))
