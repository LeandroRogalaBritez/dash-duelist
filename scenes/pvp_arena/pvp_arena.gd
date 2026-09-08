extends Node2D
# Duelo online 1v1. Só dois players — nenhum inimigo, nenhum projétil.

@onready var sound_bank: SoundBank = $SoundBank
@onready var player1: Player = $Player1
@onready var player2: Player = $Player2
@onready var hud: CanvasLayer = $PvpHud
@onready var victory_screen: CanvasLayer = $VictoryScreen

var _client_id: int = 0
var _round_started: bool = false
var _finished: bool = false

func _ready() -> void:
	if not _assign_identities():
		# O oponente desapareceu entre o menu e a arena.
		GameManager.leave_session_and_go_to_menu()
		return

	player1.global_position = $SpawnP1.global_position
	player2.global_position = $SpawnP2.global_position

	# Congelados até o host liberar o round (ver _try_start_round).
	player1.round_active = false
	player2.round_active = false

	var local_player: Player = player1 if player1.is_local() else player2
	var remote_player: Player = player2 if local_player == player1 else player1
	hud.bind(local_player, remote_player)
	hud.set_status("Aguardando o oponente...")

	player1.died.connect(_on_player_died.bind(player1))
	player2.died.connect(_on_player_died.bind(player2))

	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	OnlineNetworkManager.connection_failed.connect(_on_online_connection_failed)

	sound_bank.playMusic("background", -30.0)

	if multiplayer.is_server():
		NetworkManager.peer_world_ready.connect(_on_peer_world_ready)
		_try_start_round()
	else:
		# Nossos nós existem agora, então o host pode começar a resolver acertos.
		NetworkManager.notify_world_ready.rpc_id(1)

# Identidade derivada LOCALMENTE, sem nenhuma mensagem: o host vê
# get_peers() == [client_id]; o cliente vê get_peers() == [1] e o próprio id é
# o client_id. Os dois lados chegam ao mesmo mapeamento, e como Player1/Player2
# são nós fixos da cena, os node paths batem nos dois peers — é isso que torna
# net_apply_damage.rpc() trivialmente correto.
func _assign_identities() -> bool:
	if multiplayer.is_server():
		var peers := multiplayer.get_peers()
		if peers.is_empty():
			return false
		_client_id = peers[0]
	else:
		_client_id = multiplayer.get_unique_id()

	player1.net_init(1)
	player2.net_init(_client_id)
	return true

# ---------- início do round ----------

# Sem esta espera o host, que carrega a arena antes, poderia dashar e resolver
# um acerto antes de o Player2 existir no cliente: o RPC de dano bateria num
# node path inexistente, seria descartado, e o HP ficaria desincronizado.
func _try_start_round() -> void:
	if _round_started or not multiplayer.is_server():
		return
	if not NetworkManager.is_world_ready(_client_id):
		return
	_round_started = true
	net_start_round.rpc()

func _on_peer_world_ready(_id: int) -> void:
	_try_start_round()

@rpc("authority", "call_local", "reliable")
func net_start_round() -> void:
	player1.round_active = true
	player2.round_active = true
	hud.set_status("")

# ---------- fim do duelo ----------

func _on_player_died(who: Player) -> void:
	if not multiplayer.is_server() or _finished:
		return
	_finished = true
	var winner_id: int = _client_id if who == player1 else 1
	net_declare_winner.rpc(winner_id)

# O host declara o resultado num único RPC, em vez de cada peer inferir: dá um
# instante bem definido para congelar os dois lados e é o hook natural para uma
# revanche no futuro.
@rpc("authority", "call_local", "reliable")
func net_declare_winner(winner_peer_id: int) -> void:
	_finished = true
	player1.round_active = false
	player2.round_active = false
	hud.set_status("")
	victory_screen.show_result(winner_peer_id == multiplayer.get_unique_id())

# ---------- desconexões ----------

# Numa malha WebRTC (create_mesh) NÃO existe "servidor" do ponto de vista do
# transporte, então o Godot nunca emite server_disconnected — a saída do host
# chega ao cliente como peer_disconnected(1). Os dois lados são tratados aqui,
# no mesmo lugar; server_disconnected fica só como caminho para um transporte
# ENet futuro.
func _on_peer_disconnected(id: int) -> void:
	if _finished:
		return
	if multiplayer.is_server():
		if id != _client_id:
			return
		_end_by_disconnect(true, "O oponente saiu da partida.")
	else:
		if id != 1:
			return
		_end_by_disconnect(false, "O host encerrou a partida.")

func _on_server_disconnected() -> void:
	if _finished:
		return
	_end_by_disconnect(false, "O host encerrou a partida.")

# Backstop: o aviso de saída do host pode chegar pelo socket de sinalização
# antes de o próprio peer WebRTC perceber. Só o cliente reage — se a
# sinalização cair para o host, o jogo já está P2P e continua normalmente.
func _on_online_connection_failed(reason: String) -> void:
	if _finished or multiplayer.is_server():
		return
	_end_by_disconnect(false, reason)

func _end_by_disconnect(won: bool, reason: String) -> void:
	_finished = true
	player1.round_active = false
	player2.round_active = false
	hud.set_status("")
	victory_screen.show_result(won, reason)
