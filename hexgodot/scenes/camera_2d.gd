extends Camera2D

@export var speed := 0.9
@export var min_zoom :=0.2 # how much we can zoom OUT
@export var max_zoom := 1.0 # zoom IN
@export var zoom_step := 1.1
@export var map_rect := Rect2(-6000,-5500, 12000, 11000)  #map bounds

var is_dragging := false # no export because its not a hyperparameter
var last_mouse_position := Vector2.ZERO

func _process(delta): # additional moving through mouse buttons - not really needed
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	position += input_vector.normalized() * speed * delta / zoom.x

func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				var current_zoom = zoom.x  
				var new_zoom = current_zoom
				new_zoom /= zoom_step
				new_zoom = clamp(new_zoom, min_zoom, max_zoom)
				zoom = Vector2(new_zoom, new_zoom)
				
				var screen_half_size = get_viewport_rect().size * 0.5

				# clamp position to ensure camera stays within bounds while zooming out
				position.x = clamp(position.x, map_rect.position.x + screen_half_size.x/zoom.x, map_rect.end.x - screen_half_size.x/zoom.x)
				position.y = clamp(position.y, map_rect.position.y + screen_half_size.y/zoom.x, map_rect.end.y - screen_half_size.y/zoom.x)

			MOUSE_BUTTON_WHEEL_UP:
				var current_zoom = zoom.x  
				var new_zoom = current_zoom
				new_zoom *= zoom_step
				new_zoom = clamp(new_zoom, min_zoom, max_zoom)
				zoom = Vector2(new_zoom, new_zoom)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_dragging = true
					last_mouse_position = get_global_mouse_position() 
				else:
					is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom.x  
		var screen_half_size = get_viewport_rect().size * 0.5

		# clamp position to ensure camera stays within bounds acknowledging the zoom
		position.x = clamp(position.x, map_rect.position.x + screen_half_size.x/zoom.x, map_rect.end.x - screen_half_size.x/zoom.x)
		position.y = clamp(position.y, map_rect.position.y + screen_half_size.y/zoom.x, map_rect.end.y - screen_half_size.y/zoom.x)
