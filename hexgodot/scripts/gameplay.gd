extends Node2D

@onready var tile_map = get_node("../TileMapLayer")
@onready var units_layer = get_node("../UnitsLayer")

var selected_unit: Node2D = null
var selected_pos = null
var input_enabled = false

func start_game():
	input_enabled = true

func _unhandled_input(event):
	if not input_enabled:
		return 
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#print("click")
		var tile_pos = tile_map.local_to_map(get_global_mouse_position())
	
		if selected_unit == null:
			#print("select?")
			var clicked_unit = units_layer.get_unit_at(tile_pos)
			if clicked_unit:
				#print("selected")
				selected_unit = clicked_unit
				selected_pos = tile_pos
			return
		
		#print("can move?")
		if units_layer.can_move_unit(selected_unit, tile_pos):
				Client.move_unit(selected_pos, tile_pos)
		else:
			pass
			#print("cannot move")
		selected_unit = null

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		selected_unit = null
	
