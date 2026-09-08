extends Node
# autoload/network_manager.gd (autoload: NetworkManager)
#
# Camada de sessão AGNÓSTICA DE TRANSPORTE. Escuta apenas os sinais genéricos
# do MultiplayerAPI, então funciona igual com ENet (LAN) ou com a malha WebRTC
# do OnlineNetworkManager — quem troca o transporte é só uma linha
# (multiplayer.multiplayer_peer = ...), e nada aqui precisa saber qual é.

const MAX_PLAYERS := 2

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal peer_world_ready(id: int)

# Peers que já reportaram a própria cópia da cena de jogo carregada. Mora aqui
# no autoload, e não na cena da arena, de propósito: o node path de um autoload
# resolve em todo peer, sempre, então o report não pode ser descartado só
# porque o receptor ainda não entrou na arena.
var _world_ready_peers: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	multiplayer.connected_to_server.connect(func(): connection_succeeded.emit())
	multiplayer.server_disconnected.connect(func(): server_disconnected.emit())

func host(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func join(ip: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	# Restaura o default offline do próprio Godot em vez de deixar
	# multiplayer_peer realmente null: no 4.7, uma vez que um MultiplayerPeer
	# real foi atribuído e depois limpado para null, multiplayer.get_unique_id()
	# passa a errar permanentemente (retorna 0) pelo resto do processo em vez de
	# cair de volta no id de singleplayer. OfflineMultiplayerPeer é o mesmo
	# objeto que o Godot usa como default antes de qualquer host()/join(), então
	# isso nos devolve exatamente àquele estado.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_world_ready_peers.clear()

func is_full() -> bool:
	return multiplayer.get_peers().size() >= MAX_PLAYERS - 1

# True quando `peer_id` já avisou o host que a arena dele está carregada. O host
# usa isso para segurar o início do round: sem essa espera ele carrega a arena
# uns 300 ms antes (ele avança por sinal, o cliente por handshake) e poderia
# dashar e resolver um acerto antes de o Player2 existir no cliente — o RPC de
# dano bateria num node path inexistente, seria descartado, e o HP ficaria
# desincronizado para sempre.
func is_world_ready(peer_id: int) -> bool:
	return _world_ready_peers.has(peer_id)

@rpc("any_peer", "reliable")
func notify_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		return
	_world_ready_peers[id] = true
	peer_world_ready.emit(id)

func _on_peer_connected(id: int) -> void:
	# Rejeita só um peer genuinamente excedente. get_peers() já inclui o peer
	# deste sinal, então com o cap de 2 jogadores o primeiro cliente legítimo
	# chega com size() == 1 == MAX_PLAYERS - 1 e NÃO pode ser rejeitado.
	if multiplayer.is_server() and multiplayer.get_peers().size() > MAX_PLAYERS - 1:
		return
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	_world_ready_peers.erase(id)
	peer_disconnected.emit(id)
