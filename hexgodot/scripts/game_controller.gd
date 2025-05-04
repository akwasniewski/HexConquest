extends Node2D

@onready var unit_placer = get_node("../UnitPlacer")
@onready var world_gen= get_node("../WorldGen")
@onready var gameplay= get_node("../Gameplay")

# entry point
func _ready():
	world_gen.connect("world_generated", _on_world_generated)
	unit_placer.connect("placement_finished", _on_placement_finished)
	
	world_gen.call_deferred("run")

func _on_world_generated():
	
	unit_placer.start_placing_units()
	

func _on_placement_finished():
	gameplay.start_game()
	pass
