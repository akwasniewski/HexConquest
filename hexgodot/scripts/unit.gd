extends Node2D

@onready var count_label = get_node("CountLabel")

var count = 0
var player_id = 0


func get_count() -> int:
	return count

func set_count(value: int):
	count = value
	count_label.text = str(value)

func add_count(value: int):
	set_count(value + get_count())

func add_count_from(unit):
	add_count(unit.get_count())

func get_player_id() -> int:
	return player_id

func set_player_id(value: int):
	player_id = value
