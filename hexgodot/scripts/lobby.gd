extends Control

func _ready() -> void:
	Client.players_updated.connect(_on_players_updated)
	show_active_players()
	show_game_id()
	update_start_button_visibility()
	$StartGameButton.pressed.connect(_on_start_game_button_pressed)

func _on_players_updated() -> void:
	show_active_players()

func show_active_players() -> void:
	var players_list = get_node("PlayersList")

	# Clear current list
	for child in players_list.get_children():
		players_list.remove_child(child)
		child.queue_free()

	# Add new players
	for player in Client.active_players:
		var label = Label.new()
		label.text = "Player %s: %s" % [int(player.get("player_id")), player.get("username")]
		players_list.add_child(label)

func show_game_id() -> void:
	var label = get_node("GameIdLabel")
	label.text = "Game ID: %s" % Client.game_id 

func update_start_button_visibility():
	var button = get_node("StartGameButton")
	var pid= Client.player_id

	if pid == 0:
		button.visible = true
	else:
		button.visible = false

func _on_start_game_button_pressed() -> void:
	Client.start_game()
