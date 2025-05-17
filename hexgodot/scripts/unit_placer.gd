extends Node2D

@onready var tile_map = get_node("../TileMapLayer")
@onready var units_layer = get_node("../UnitsLayer")

signal placement_finished

const TOTAL_UNITS_TO_PLACE = 3
var units_to_place = TOTAL_UNITS_TO_PLACE
var input_enabled = false


func start_placing_units():
	input_enabled = true
	#set_process_input(true)

func _unhandled_input(event):
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_pos = tile_map.local_to_map(get_global_mouse_position())
		try_place_unit(tile_pos)
		#get_viewport().set_input_as_handled()

func try_place_unit(tile_pos: Vector2i):
	if units_to_place <= 0:
		return
	if unit_can_be_placed_at(tile_pos):
		place_unit(tile_pos)


func unit_can_be_placed_at(tile_pos: Vector2i) -> bool:
	var tile_is_on_map = true #TODO change this !!!
	var tile_is_free = units_layer.get_unit_at(tile_pos) == null
	return (tile_is_on_map && tile_is_free)

func place_unit(tile_pos: Vector2i):
	print("unit placed")

	Client.add_unit(tile_pos)
	units_to_place-=1
	if units_to_place <= 0:
		stop_placing_units()

func stop_placing_units():
		input_enabled = false
		set_process_input(false)
		emit_signal("placement_finished")
