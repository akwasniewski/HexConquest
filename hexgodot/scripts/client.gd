extends Node

var ws := WebSocketPeer.new()
var is_connected := false
var pending_message: Dictionary = {}
var player_id := -1
var game_id := -1
var map_seed := 2137
var active_players: Array = []
signal players_updated
func _ready():
	set_process(true)

func _process(_delta):
	ws.poll()

	var state = ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not is_connected:
		is_connected = true
		print("Connected to server")
		# Send any pending message once connected
		if pending_message.size() > 0:
			send(pending_message)
			pending_message.clear()

	elif state == WebSocketPeer.STATE_CLOSED and is_connected:
		is_connected = false
		print("Disconnected from server")

	# Handle incoming messages
	while ws.get_available_packet_count() > 0:
		var raw = ws.get_packet().get_string_from_utf8()
		handle_message(raw)

func connect_to_server(message_to_send: Dictionary):
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		# If already connected, send the message immediately
		send(message_to_send)
	else:
		# If not connected, save the message to send later
		var err = ws.connect_to_url("ws://localhost:7777/ws")
		if err != OK:
			push_error("Failed to connect to server")
		else:
			# Store the message to be sent after connection
			pending_message = message_to_send
			print("Connecting to server...")


func handle_message(raw: String):
	var json = JSON.new()
	var result = json.parse(raw)
	if result != OK:
		push_error("JSON parse error")
		return
	
	var msg = json.get_data()
	var msg_type = msg.get("type", "")
	var payload = msg.get("payload", {})

	match msg_type:
		"GameJoined":
			player_id = payload.get("player_id", -1)
			game_id = payload.get("game_id", -1)
			print("Joined game #%s as player #%s" % [game_id, player_id])
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		"GameCreated":
			player_id = payload.get("player_id", -1)
			game_id = payload.get("game_id", -1)
			print("Created game #%s as player #%s" % [game_id, player_id])
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		"ActivePlayersList":
			var players = payload.get("players", [])
			print("Received list of active players:")
			for player_info in players:
				var pid = int(player_info.get("player_id", -1))
				var username = player_info.get("username", "")
				print(" - #%s: %s" % [pid, username])
			active_players = players 
		"PlayerJoined":
			var pid = payload.get("player_id")
			var username = payload.get("username", "")
			if player_id != pid or player_id==0:
				active_players.append({
					"player_id": pid,
					"username": username
				})		
				print("player joined #%s, #%s", pid, username)
			players_updated.emit()
		"StartGame":
			map_seed = payload.get("map_seed", -1)
			get_tree().change_scene_to_file("res://scenes/game.tscn")
		"Error":
			var message = payload.get("message", "")
			print("Server error: %s" % message)
		_:
			print("Unknown message type: ", msg_type)


func send(data: Dictionary):
	if not is_connected:
		# If not connected, store the message to send later
		print("Not connected. Message will be sent once connected.")
		pending_message = data
		return

	# If connected, send the message
	var msg = JSON.stringify(data)
	ws.send_text(msg)

func create_game(username: String):
	var message = {
		"type": "CreateGame",
		"payload": {
			"username": username
		}
	}
	connect_to_server(message)

func join_game(username: String, game_id: int):
	var message = {
		"type": "JoinGame",
		"payload": {
			"username": username,
			"game_id": game_id
		}
	}
	connect_to_server(message)

func start_game():
	print("starting game")
	var message = {
		"type": "StartGame",
	}
	send(message)
