extends Node2D

#@onready var label = $Label
@onready var label = get_node("Label")

func set_count(value: int):
	label.text = str(value)
