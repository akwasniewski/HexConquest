extends Node2D

@onready var tile_map = get_node("../TileMapLayer")
@onready var units_layer = get_node("../UnitsLayer")
@onready var selection_frame = get_node("../SelectedTile")
var selected_unit: Node2D = null
var selected_pos = null
var input_enabled = false

var mouse_pressed_pos := Vector2.ZERO
var mouse_drag_threshold := 32  # pixels
var is_dragging := false


func start_game():
	input_enabled = true

func _unhandled_input(event):
	if not input_enabled:
		return 
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_pressed_pos = event.position
				is_dragging = false  
			else:
				if not is_dragging and mouse_pressed_pos.distance_to(event.position) < mouse_drag_threshold:
					_handle_left_click(event.position)

	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if mouse_pressed_pos.distance_to(event.position) >= mouse_drag_threshold:
			is_dragging = true

func _handle_left_click(mouse_pos: Vector2):
	var tile_pos = tile_map.local_to_map(get_global_mouse_position())
	
	if selected_unit == null:
		var clicked_unit = units_layer.get_unit_at(tile_pos)
		if clicked_unit:
			selected_unit = clicked_unit
			selected_pos = tile_pos
			selection_frame.position = tile_map.map_to_local(tile_pos)
			selection_frame.show()
		return
	
	if units_layer.can_move_unit(selected_unit, tile_pos):
		Client.move_unit(selected_pos, tile_pos)
	
	selected_unit = null
	selection_frame.hide()
