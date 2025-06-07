extends Node2D

@onready var tile_map = get_node("../TileMapLayer")
@onready var units_layer = get_node("../UnitsLayer")

var player_influence_at = {}
var sprite_at = {}

const INFLUENCE_RANGE = 2
#const FAKE_PLAYER_ID = -1

const ALPHA = 0.3

var colors = [
	Color(1, 0, 0, ALPHA),   # Red
	Color(0, 1, 0, ALPHA),   # Green
	Color(0, 0, 1, ALPHA),   # Blue
	Color(1, 1, 0, ALPHA),   # Yellow
	Color(1, 0, 1, ALPHA),   # Magenta
	Color(0, 1, 1, ALPHA),   # Cyan
	Color(1, 0.5, 0, ALPHA), # Orange
	Color(0.5, 0, 1, ALPHA), # Purple
	Color(0.5, 0.5, 0.5, ALPHA), # Gray
]

var pastel_colors = [
	Color(1.0, 0.8, 0.8, ALPHA),  # Pastel Red
	Color(0.8, 1.0, 0.8, ALPHA),  # Pastel Green
	Color(0.8, 0.8, 1.0, ALPHA),  # Pastel Blue
	Color(1.0, 1.0, 0.8, ALPHA),  # Pastel Yellow
	Color(1.0, 0.8, 1.0, ALPHA),  # Pastel Magenta
	Color(0.8, 1.0, 1.0, ALPHA),  # Pastel Cyan
	Color(1.0, 0.9, 0.8, ALPHA),  # Peach
	Color(0.9, 0.8, 1.0, ALPHA),  # Lavender
	Color(0.95, 0.95, 0.95, ALPHA), # Very light gray
	Color(0.9, 1.0, 0.9, ALPHA)   # Mint
]


func report_unit_placed(pos: Vector2i, player_id: int):
	var tiles_in_influence_range = tile_map.hexes_in_range(pos, INFLUENCE_RANGE)
	#var tiles_to_update = tile_map.hexes_in_range(pos, INFLUENCE_RANGE)
	#print("repunpl")
	
	var influenced_tiles = []
	for tile in tiles_in_influence_range:
		var unit = units_layer.get_unit_at(pos)
		if unit == null || unit.get_player_id() == player_id:
			influenced_tiles.push_back(tile) 
	
	update_influence(influenced_tiles, player_id)
	redraw_sprites(influenced_tiles, player_id)


func update_influence(tiles, player_id: int):
	for tile in tiles:
		player_influence_at[tile] = player_id


func redraw_sprites(tiles, player_id):
	for tile in tiles:
		delete_sprite_at(tile)
	
	for tile in tiles:
		draw_sprite(tile, player_id)


func delete_sprite_at(tile):
	var sprite = sprite_at.get(tile)
	if sprite == null:
		# this should be unreachable
		return
	
	sprite.queue_free()
	sprite_at.erase(tile)


func draw_sprite(tile, player_id):
	#print("draw")

	#if !tile_map.is_part_of_map(tile):
		#return
	var tile_player_id = player_influence_at.get(tile)
	if tile_player_id == null:
		return
	
	#print("draw2")
	
	
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/tiles/hexagon.png")
	sprite.position = tile_map.map_to_local(tile)
	
	sprite.modulate.a = 0.5
	#var color = pastel_colors[player_id]
	var color = colors[player_id]
	sprite.modulate = color
	
	add_child(sprite)
	#print("added hex sprite at", tile.x, tile.y)
	sprite_at[tile] = sprite
