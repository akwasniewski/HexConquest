
extends Control
@onready var create_button = $CreateButton
@onready var join_button = $JoinButton
@onready var username_input = $UsernameInput
@onready var game_id_input = $GameIdInput  # assuming it's a LineEdit
@onready var loading_spinner = $LoadingSpinner
@onready var error_dialogue = $ErrorDialogue
func _ready():
	create_button.pressed.connect(_on_CreateButton_pressed)
	join_button.pressed.connect(_on_JoinButton_pressed)
	Client.connection_failed.connect(_on_connection_failed)

func _on_CreateButton_pressed():
	var username = username_input.text
	_start_loading()
	Client.create_game(username)

func _on_JoinButton_pressed():
	var username = username_input.text
	var game_id = int(game_id_input.text)  # convert to integer
	_start_loading()
	Client.join_game(username, game_id)

func _on_connection_failed():
	create_button.disabled = false
	join_button.disabled = false
	loading_spinner.visible = false
	error_dialogue.visible= true
	print("Connection failed")

func _start_loading():
	create_button.disabled = true
	join_button.disabled = true
	loading_spinner.visible = true

func _process(delta):
	if loading_spinner.visible:
		loading_spinner.rotation += 5 * delta 
