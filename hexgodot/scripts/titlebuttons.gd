
extends Control
@onready var create_button = $CreateButton
@onready var join_button = $JoinButton
@onready var username_input = $UsernameInput
@onready var game_id_input = $GameIdInput  # assuming it's a LineEdit

func _ready():
	create_button.pressed.connect(_on_CreateButton_pressed)
	join_button.pressed.connect(_on_JoinButton_pressed)

func _on_CreateButton_pressed():
	var username = username_input.text
	Client.create_game(username)

func _on_JoinButton_pressed():
	var username = username_input.text
	var game_id = int(game_id_input.text)  # convert to integer
	Client.join_game(username, game_id)
