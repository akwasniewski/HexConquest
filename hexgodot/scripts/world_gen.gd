extends Node2D

@export var noise_height_text : NoiseTexture2D
var noise : Noise
@onready var tile_map = get_node("../TileMapLayer")

var source_id = 0
var water_atlas = Vector2i(1, 2)  # różne kafelki wody
var land_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3,0), Vector2i(4,0), Vector2i(0,1), Vector2i(1,1), Vector2i(0,0)]  # różne kafelki trawy
var dirt_tiles = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(0,2)]  # różne kafelki ziemi
var city_tile = Vector2i(2, 2)  # przykładowy kafelek miasta
var port_tile = Vector2i(4, 2)  # przykładowy kafelek portu
var placed_cities = []
var placed_ports = []
var neighbour_cells = [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0)]
var neighbour_cells_even_columns = [Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(-1,-1), Vector2i(0,1)]
var neighbour_cell_odd_columns = [Vector2i(1,1), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,1), Vector2i(0,1), Vector2i(-1,0)]
const MIN_DIST_BETWEEN_STRUCTURES = 4

signal world_generated

var width : int = 100
var height : int = 100
var noise_arr = []
var seed : int
var dirt_tiles_coords = []

func pseudo_random(x: int, y: int, ) -> int:
	var hash = int((x * 374761393 + y * 668265263 + seed * 982451653) & 0x7fffffff)
	return hash % 2137
	
func pseudo_random_range(index: int, seed: int, min_val: int, max_val: int) -> int:
	var range_size = max_val - min_val + 1
	var hash = int((index * 374761393 + seed * 668265263) & 0x7fffffff)
	return (hash % range_size) + min_val
	
func run():
	noise = noise_height_text.noise
	noise.seed = Client.map_seed;
	seed = Client.map_seed;
	generate_world()
	place_structures()
	emit_signal("world_generated")

func generate_world():
	for x in range(-width/2,width/2):
		for y in range(-height/2, height/2):
			var noise_val = noise.get_noise_2d(x,y)
			#print(noise_val)
			noise_arr.append(noise_val)
			if noise_val > 0:
				var tile = land_tiles[pseudo_random(x,y)%land_tiles.size()]
				tile_map.set_cell(Vector2i(x,y), source_id, tile)
			elif noise_val <= -0.2:
				tile_map.set_cell(Vector2i(x,y), source_id, water_atlas)
			elif noise_val <= 0:
				var tile = dirt_tiles[pseudo_random(y,x)%dirt_tiles.size()]
				tile_map.set_cell(Vector2i(x,y), source_id, tile)
				dirt_tiles_coords.append(Vector2i(x, y))
				
func is_near_structure(pos: Vector2i, structures: Array, min_dist: int) -> bool:
	for other in structures:
		if pos.distance_to(other) < min_dist:
			return true
	return false
	
func is_near_water(pos: Vector2i) -> bool:
	# Sprawdzamy wszystkie sąsiednie kafelki w promieniu 1 wokół
	#var neighbour_cells = neighbour_cells_even_columns
	#if pos.y %2 == 0:
		#neighbour_cells = neighbour_cell_odd_columns
		
	for neighbour in neighbour_cells:
		var n = pos + neighbour
		print(pos);
		print(n);
		# Sprawdzamy, czy sąsiedni kafelek jest wodą
		var tile = tile_map.get_cell_atlas_coords(n)
		if tile == water_atlas:
			return true
	return false


	
func place_structures():
	#place cities
	for i in range(height*width/2):
		var x = pseudo_random_range(i*27, seed, -width/2, width/2)
		var y = pseudo_random_range(i*37, seed, -height/2, height/2)
		var pos = Vector2i(x, y)
		var tile = tile_map.get_cell_atlas_coords(pos)

		# Miasto na lądzie, nie przy wodzie i nie blisko innych miast
		if land_tiles.has(tile) and not is_near_water(pos) and not is_near_structure(pos, placed_cities, MIN_DIST_BETWEEN_STRUCTURES):
			tile_map.set_cell(pos, source_id, city_tile)
			placed_cities.append(pos)
			
	for i in range(1000):
		var pos = dirt_tiles_coords[pseudo_random(i*19, i*37)%dirt_tiles_coords.size()]
		var tile = tile_map.get_cell_atlas_coords(pos)
		
		## Port na lądzie obok wody, nie za blisko innych portów i miast
		if is_near_water(pos) and not is_near_structure(pos, placed_ports + placed_cities, MIN_DIST_BETWEEN_STRUCTURES):
			tile_map.set_cell(pos, source_id, port_tile)
			placed_ports.append(pos)
			

			
	print("highest ", noise_arr.max())
	print("lowest ", noise_arr.min())
