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

const MIN_DIST_BETWEEN_STRUCTURES = 4
var width : int = 100
var height : int = 100
var noise_arr = []
var dirt_tiles_coords = []
var rng = RandomNumberGenerator.new()
var tile_info: Dictionary = {}

signal world_generated
	
func run():
	noise = noise_height_text.noise
	noise.seed = Client.map_seed;
	rng.seed = Client.map_seed
	generate_world()
	place_structures()
	emit_signal("world_generated")

func generate_world():
	for x in range(-width/2,width/2):
		for y in range(-height/2, height/2):
			var noise_val = noise.get_noise_2d(x,y)
			noise_arr.append(noise_val)
			
			if noise_val > 0:
				var tile = land_tiles[rng.randi()%land_tiles.size()]
				tile_map.set_cell(Vector2i(x,y), source_id, tile)
				var data := MyTileData.new(Vector2i(x,y))
				tile_info[Vector2i(x,y)] = data
			elif noise_val <= -0.2:
				tile_map.set_cell(Vector2i(x,y), source_id, water_atlas)
				var data := MyTileData.new(Vector2i(x,y), false, false, true, -1)
				tile_info[Vector2i(x,y)] = data
			elif noise_val <= 0:
				var tile = dirt_tiles[rng.randi()%dirt_tiles.size()]
				tile_map.set_cell(Vector2i(x,y), source_id, tile)
				dirt_tiles_coords.append(Vector2i(x, y))
				var data := MyTileData.new(Vector2i(x,y))
				tile_info[Vector2i(x,y)] = data
				
func is_near_structure(pos: Vector2i, structures: Array, min_dist: int) -> bool:
	for other in structures:
		if pos.distance_to(other) < min_dist:
			return true
	return false
	
func is_near_water(pos: Vector2i) -> bool:
	var neighbour_cells = tile_info[pos].get_neighbors(Vector2i(width/2,height/2))
	for neighbour in neighbour_cells:
		if tile_info[neighbour].is_water == true:
			return true
	return false


	
func place_structures():
	#place cities
	for i in range(height*width/2):
		var x = rng.randi_range(-width/2, width/2)
		var y = rng.randi_range(-height/2, height/2)
		var pos = Vector2i(x, y)
		var tile = tile_map.get_cell_atlas_coords(pos)

		# Miasto na lądzie, nie przy wodzie i nie blisko innych miast
		if land_tiles.has(tile) and not is_near_water(pos) and not is_near_structure(pos, placed_cities, MIN_DIST_BETWEEN_STRUCTURES):
			tile_map.set_cell(pos, source_id, city_tile)
			placed_cities.append(pos)
			tile_info[pos].set_city(true)
			
	for i in range(1000):
		var pos = dirt_tiles_coords[rng.randi()%dirt_tiles_coords.size()]
		var tile = tile_map.get_cell_atlas_coords(pos)
		
		## Port na lądzie obok wody, nie za blisko innych portów i miast
		if is_near_water(pos) and not is_near_structure(pos, placed_ports + placed_cities, MIN_DIST_BETWEEN_STRUCTURES):
			tile_map.set_cell(pos, source_id, port_tile)
			placed_ports.append(pos)
			placed_cities.append(pos)
			tile_info[pos].set_city(true)
			tile_info[pos].set_port(true)
			

	Client.send_cities(placed_cities)	
	Client.send_ports(placed_ports)	
	print("highest ", noise_arr.max())
	print("lowest ", noise_arr.min())
