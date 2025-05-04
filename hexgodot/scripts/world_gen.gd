extends Node2D

@export var noise_height_text : NoiseTexture2D
var noise : Noise
@onready var tile_map = get_node("../TileMapLayer")

var source_id = 0
var water_atlas = Vector2i(1, 2)  # różne kafelki wody
var land_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3,0), Vector2i(4,0), Vector2i(0,1), Vector2i(0,2)]  # różne kafelki trawy
var dirt_tiles = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(0,2)]  # różne kafelki ziemi
var city_tile = Vector2i(2, 2)  # przykładowy kafelek miasta
var port_tile = Vector2i(4, 2)  # przykładowy kafelek portu
var placed_cities = []
var placed_ports = []
var neighbour_cells_even_columns = [Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(-1,-1), Vector2i(0,1)]
var neighbour_cell_odd_columns = [Vector2i(1,1), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,1), Vector2i(0,1), Vector2i(-1,0)]
const MIN_DIST_BETWEEN_STRUCTURES = 4

signal world_generated

var width : int = 100
var height : int = 100
var noise_arr = []

	
func run():
	randomize()
	noise = noise_height_text.noise
	noise.seed = Client.map_seed;
	generate_world()
	place_structures()
	emit_signal("world_generated")

func generate_world():
	for x in range(-width/2,width/2):
		for y in range(-height/2, height/2):
			var noise_val = noise.get_noise_2d(x,y)
			#print(noise_val)
			noise_arr.append(noise_val)
			if noise_val > -0.1:
				var tile = land_tiles[randi()%land_tiles.size()]
				tile_map.set_cell(Vector2i(x,y), source_id, tile)
			elif noise_val <= -0.2:
				tile_map.set_cell(Vector2i(x,y), source_id, water_atlas)
			elif noise_val <= -0.1:
				var tile = dirt_tiles[randi()%dirt_tiles.size()]
				tile_map.set_cell(Vector2i(x,y), source_id, tile)
				
func is_near_structure(pos: Vector2i, structures: Array, min_dist: int) -> bool:
	for other in structures:
		if pos.distance_to(other) < min_dist:
			return true
	return false
	
func is_near_water(pos: Vector2i) -> bool:
	# Sprawdzamy wszystkie sąsiednie kafelki w promieniu 1 wokół
	var neighbour_cells = neighbour_cells_even_columns
	if pos.y %2 == 0:
		neighbour_cells = neighbour_cell_odd_columns
		
	for neighbour in neighbour_cells:
		var n = pos + neighbour
		# Sprawdzamy, czy sąsiedni kafelek jest wodą
		var tile = tile_map.get_cell_atlas_coords(n)
		if tile == water_atlas:
			return true
	return false


	
func place_structures():
	var cities_to_place = 200
	var ports_to_place = 125
	
	while cities_to_place > 0:
		var x = randi_range(-width/2, width/2)
		var y = randi_range(-height/2, height/2)
		var pos = Vector2i(x, y)
		var tile = tile_map.get_cell_atlas_coords(pos)

		# Miasto na lądzie, nie przy wodzie i nie blisko innych miast
		if land_tiles.has(tile) and not is_near_water(pos) and not is_near_structure(pos, placed_cities, MIN_DIST_BETWEEN_STRUCTURES):
			tile_map.set_cell(pos, source_id, city_tile)
			placed_cities.append(pos)
			cities_to_place -= 1

	while ports_to_place > 0:
		var x = randi_range(-width/2, width/2)
		var y = randi_range(-height/2, height/2)
		var pos = Vector2i(x, y)
		var tile = tile_map.get_cell_atlas_coords(pos)

		# Port na lądzie obok wody, nie za blisko innych portów i miast
		if land_tiles.has(tile) and is_near_water(pos) and not is_near_structure(pos, placed_ports + placed_cities, MIN_DIST_BETWEEN_STRUCTURES):
			tile_map.set_cell(pos, source_id, port_tile)
			placed_ports.append(pos)
			ports_to_place -= 1

			
	print("highest ", noise_arr.max())
	print("lowest ", noise_arr.min())
