extends Node2D

@export var noise_height_text : NoiseTexture2D
var noise : Noise
@onready var tile_map = $TileMapLayer

var source_id = 0
var water_atlas = Vector2i(3,0)
var land_atlas = Vector2i(1,0)
var dirt_atlas = Vector2i(0,0)

var width : int = 100
var height : int = 100
var noise_arr = []
func _ready():
	noise = noise_height_text.noise
	generate_world()

func generate_world():
	for x in range(-width/2,width/2):
		for y in range(-height/2, height/2):
			var noise_val = noise.get_noise_2d(x,y)
			#print(noise_val)
			noise_arr.append(noise_val)
			if noise_val > -0.1:
				tile_map.set_cell(Vector2i(x,y), source_id, land_atlas)
			elif noise_val <= -0.2:
				tile_map.set_cell(Vector2i(x,y), source_id, water_atlas)
			elif noise_val <= -0.1:
				tile_map.set_cell(Vector2i(x,y), source_id, dirt_atlas)
				

	print("highest ", noise_arr.max())
	print("lowest ", noise_arr.min())
