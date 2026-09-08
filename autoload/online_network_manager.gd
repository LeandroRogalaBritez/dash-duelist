extends Node
# autoload/online_network_manager.gd (autoload: OnlineNetworkManager)
#
# Conexão online via WebRTC. Um servidor de sinalização WebSocket é usado só
# para trocar SDP/ICE entre os dois jogadores; o tráfego de jogo vai direto
# peer-to-peer, atravessando NAT com a ajuda de STUN público do Google — é isso
# que permite jogar de fora da LAN.
#
# Depois que a malha WebRTC está pronta, este script atribui o peer resultante a
# multiplayer.multiplayer_peer. Dali em diante o NetworkManager assume
# normalmente (ele escuta os sinais genéricos do MultiplayerAPI, não o
# transporte): peer_connected, connection_succeeded, o handshake de world-ready
# e todos os RPCs de gameplay funcionam sem nenhuma mudança.
#
# Uso:
#   OnlineNetworkManager.host_online("sala1")
#   OnlineNetworkManager.join_online("sala1")

# Servidor de sinalização compartilhado com o project-adventure. Para testar
# local, suba `node server/signaling/server.js` de lá e troque para
# "ws://127.0.0.1:3000".
const SIGNALING_URL := "wss://signal-server-webrtc.onrender.com"

# O servidor de sinalização é compartilhado com outros projetos, então todo
# código de sala digitado pelo jogador ganha este prefixo. Sem ele, "sala1" do
# Dash Duelist e "sala1" do project-adventure seriam a MESMA sala e os dois
# jogos tentariam se conectar entre si.
const ROOM_PREFIX := "dd-"

const ICE_SERVERS := [
	{ "urls": ["stun:stun.l.google.com:19302"] },
	{ "urls": ["stun:stun1.l.google.com:19302"] },
]

signal room_created(room: String)
signal joined_room(room: String)
signal connection_failed(reason: String)

var _socket := WebSocketPeer.new()
var _my_peer_id: String = ""

var _rtc_multiplayer := WebRTCMultiplayerPeer.new()
var _peer_connections: Dictionary = {} # peerId (String) -> WebRTCPeerConnection
var _next_int_id: int = 2 # host é sempre o id 1 do Godot
var _id_map: Dictionary = {} # peerId (String) -> id inteiro do Godot

# Último estado impresso de cada WebRTCPeerConnection, só para logar transições
# (connection_state, gathering_state). É o que permite diagnosticar negociação
# travada — em especial CONNECTED sem peer_connected, que é a armadilha do canal
# de dados id 1 duplicado descrita em _create_peer_connection().
var _debug_last_state: Dictionary = {} # peerId -> [connection_state, gathering_state]

func _process(_delta: float) -> void:
	# WebSocketPeer é um peer cru: sem poll() a cada frame nada chega.
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count() > 0:
			_on_signaling_message(_socket.get_packet().get_string_from_utf8())
	_debug_poll_peer_states()

func _debug_poll_peer_states() -> void:
	for peer_id in _peer_connections.keys():
		var conn: WebRTCPeerConnection = _peer_connections[peer_id]
		var cur := [conn.get_connection_state(), conn.get_gathering_state()]
		if _debug_last_state.get(peer_id) != cur:
			_debug_last_state[peer_id] = cur
			print("[OnlineNetworkManager] peer %s: connection_state=%s gathering_state=%s" % [
				peer_id,
				_debug_connection_state_name(cur[0]),
				_debug_gathering_state_name(cur[1]),
			])

func _debug_connection_state_name(state: int) -> String:
	match state:
		WebRTCPeerConnection.STATE_NEW: return "NEW"
		WebRTCPeerConnection.STATE_CONNECTING: return "CONNECTING"
		WebRTCPeerConnection.STATE_CONNECTED: return "CONNECTED"
		WebRTCPeerConnection.STATE_DISCONNECTED: return "DISCONNECTED"
		WebRTCPeerConnection.STATE_FAILED: return "FAILED"
		WebRTCPeerConnection.STATE_CLOSED: return "CLOSED"
		_: return "UNKNOWN(%d)" % state

func _debug_gathering_state_name(state: int) -> String:
	match state:
		WebRTCPeerConnection.GATHERING_STATE_NEW: return "NEW"
		WebRTCPeerConnection.GATHERING_STATE_GATHERING: return "GATHERING"
		WebRTCPeerConnection.GATHERING_STATE_COMPLETE: return "COMPLETE"
		_: return "UNKNOWN(%d)" % state

# ---------- API pública ----------

func room_name(room: String) -> String:
	return ROOM_PREFIX + room

func host_online(room: String) -> void:
	_reset_state()
	await _connect_to_signaling_server()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_send({ "type": "create_room", "room": room_name(room) })

func join_online(room: String) -> void:
	_reset_state()
	await _connect_to_signaling_server()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_send({ "type": "join_room", "room": room_name(room) })

# Fecha o socket de sinalização. Ele só é necessário durante a negociação — o
# jogo em si já corre direto peer-to-peer — então deixá-lo aberto pela sessão
# inteira só mantém a sala viva no servidor e trava o código para uma próxima
# partida. Chamado por GameManager.leave_session().
func close_signaling() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_peer_connections.clear()
	_debug_last_state.clear()
	_id_map.clear()

# ---------- Conexão com o servidor de sinalização ----------

func _reset_state() -> void:
	_peer_connections.clear()
	_debug_last_state.clear()
	_id_map.clear()
	_next_int_id = 2
	_rtc_multiplayer = WebRTCMultiplayerPeer.new()
	_socket = WebSocketPeer.new()

func _connect_to_signaling_server() -> void:
	var err := _socket.connect_to_url(SIGNALING_URL)
	if err != OK:
		connection_failed.emit("Não foi possível conectar ao servidor de sinalização")
		return
	# O free tier do Render dorme: o primeiro connect da sessão pode levar
	# 30–60 s de cold start. Este loop só espera, não tem timeout de propósito.
	while _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_socket.poll()
		await get_tree().process_frame
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connection_failed.emit("Falha ao abrir WebSocket com o servidor de sinalização")

func _send(data: Dictionary) -> void:
	_socket.send_text(JSON.stringify(data))

# ---------- Tratamento de mensagens do servidor ----------

func _on_signaling_message(raw: String) -> void:
	var msg = JSON.parse_string(raw)
	if msg == null:
		return

	match msg.get("type", ""):
		"room_created":
			_my_peer_id = msg["peerId"]
			_setup_multiplayer_peer(1)
			room_created.emit(msg["room"])

		"joined_room":
			_my_peer_id = msg["peerId"]
			var host_peer_id: String = msg["hostPeerId"]
			var my_int_id := _next_int_id
			_next_int_id += 1
			_id_map[_my_peer_id] = my_int_id
			_id_map[host_peer_id] = 1
			_setup_multiplayer_peer(my_int_id)
			_create_peer_connection(host_peer_id, true) # client inicia a oferta
			joined_room.emit(msg["room"])

		"new_peer":
			# Só o host recebe isso, quando um client novo entra na sala.
			var peer_id: String = msg["peerId"]
			var int_id := _next_int_id
			_next_int_id += 1
			_id_map[peer_id] = int_id
			_create_peer_connection(peer_id, false) # host espera a oferta

		"signal":
			_handle_signal(msg["from"], msg["data"])

		"peer_left":
			var peer_id: String = msg["peerId"]
			if _id_map.has(peer_id):
				_rtc_multiplayer.remove_peer(_id_map[peer_id])
				_id_map.erase(peer_id)
			_peer_connections.erase(peer_id)

		"host_left":
			connection_failed.emit("O host encerrou a sala")

		"error":
			connection_failed.emit(msg.get("message", "Erro desconhecido"))

# ---------- WebRTC ----------

func _setup_multiplayer_peer(my_int_id: int) -> void:
	_rtc_multiplayer.create_mesh(my_int_id)
	# A partir desta linha tudo é agnóstico de transporte: NetworkManager, os
	# @rpc e os MultiplayerSynchronizer funcionam idênticos ao ENet.
	multiplayer.multiplayer_peer = _rtc_multiplayer

func _create_peer_connection(remote_peer_id: String, initiate: bool) -> void:
	var conn := WebRTCPeerConnection.new()
	conn.initialize({ "iceServers": ICE_SERVERS })
	_peer_connections[remote_peer_id] = conn

	var int_id: int = _id_map[remote_peer_id]

	# add_peer() já cria sozinho os canais de dados negociados que o
	# WebRTCMultiplayerPeer usa (ids 1/2/3 — reliable/ordered/unreliable).
	# Não criar um canal manualmente aqui: um create_data_channel(id=1) antes
	# disso duplica o id 1 no mesmo WebRTCPeerConnection e o canal do
	# add_peer() nunca abre de verdade — a conexão RTC fica CONNECTED, mas
	# peer_connected nunca dispara porque ele exige o canal aberto.
	_rtc_multiplayer.add_peer(conn, int_id)

	conn.session_description_created.connect(
		func(type: String, sdp: String) -> void:
			print("[OnlineNetworkManager] session_description_created type=%s for peer %s" % [type, remote_peer_id])
			conn.set_local_description(type, sdp)
			_send({
				"type": "signal",
				"to": remote_peer_id,
				"data": { "sdp_type": type, "sdp": sdp },
			})
	)

	conn.ice_candidate_created.connect(
		func(media: String, index: int, name: String) -> void:
			print("[OnlineNetworkManager] ice_candidate_created for peer %s" % remote_peer_id)
			_send({
				"type": "signal",
				"to": remote_peer_id,
				"data": { "ice_media": media, "ice_index": index, "ice_name": name },
			})
	)

	if initiate:
		conn.create_offer()

func _handle_signal(from_peer_id: String, data: Dictionary) -> void:
	if not _peer_connections.has(from_peer_id):
		print("[OnlineNetworkManager] signal de peer desconhecido %s, ignorando" % from_peer_id)
		return
	var conn: WebRTCPeerConnection = _peer_connections[from_peer_id]

	if data.has("sdp_type"):
		print("[OnlineNetworkManager] signal recebido sdp_type=%s de %s" % [data["sdp_type"], from_peer_id])
		# O WebRTCPeerConnection do Godot não tem create_answer(): entregar uma
		# offer remota via set_remote_description() já gera a answer
		# internamente e dispara session_description_created para ela.
		conn.set_remote_description(data["sdp_type"], data["sdp"])
	elif data.has("ice_media"):
		print("[OnlineNetworkManager] ice candidate recebido de %s" % from_peer_id)
		conn.add_ice_candidate(data["ice_media"], data["ice_index"], data["ice_name"])
