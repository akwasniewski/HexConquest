extends Node
const USE_LOCAL := false
var ws_url := ""
var ws := WebSocketPeer.new()
var is_connected := false
var pending_message: Dictionary = {}
var player_id := -1
var game_id := -1
var map_seed := 2137
var active_players: Array = []
signal players_updated
func _ready():
	if USE_LOCAL:
		ws_url = "ws://127.0.0.1:7777/ws"
	else:
		ws_url = "wss://akwasniewski.eu/hexserver"
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
		var err = ws.connect_to_url(ws_url)


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
		"AddUnit":
			var units_layer =  get_tree().get_root().get_node("game/UnitsLayer")
			var pid = payload.get("player_id")
			var position_x = payload.get("position_x")
			var position_y = payload.get("position_y")
			var count = payload.get("count")
			units_layer.add_unit_at(pid, Vector2i(position_x, position_y), count)
		"MoveUnit":
			print("Move received")
			var units_layer =  get_tree().get_root().get_node("game/UnitsLayer")
			var from_position_x = payload.get("from_position_x")
			var from_position_y = payload.get("from_position_y")
			var to_position_x = payload.get("to_position_x")
			var to_position_y = payload.get("to_position_y")
			units_layer.move_unit(Vector2i(from_position_x, from_position_y), Vector2i(to_position_x, to_position_y))
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

func add_unit(position: Vector2i):
	var message = {
		"type": "AddUnit",
		"payload": {
			"position_x": position.x,
			"position_y": position.y,
		}
	}
	send(message)

func move_unit(from_position: Vector2i, to_position: Vector2i):
	var message = {
		"type": "MoveUnit",
		"payload": {
			"from_position_x": from_position.x,
			"from_position_y": from_position.y,
			"to_position_x": to_position.x,
			"to_position_y": to_position.y,
		}
	}
	send(message)

func attack(from_position: Vector2i, to_position: Vector2i):
	var message = {
		"type": ""
	}
func send_cities(cities: Array):
	var cities_payload = cities.map(func(v):
		return {"x": v.x, "y": v.y}
	)
	if player_id==0:
		var message = {
			"type": "SendCities",
			"payload": {
				"cities": cities_payload
			}
		}
		send(message)

func send_ports(ports: Array):
	var ports_payload = ports.map(func(v):
		return {"x": v.x, "y": v.y}
	)
	if player_id==0:
		var message = {
			"type": "SendPorts",
			"payload": {
				"ports": ports_payload
			}
		}
		send(message)
