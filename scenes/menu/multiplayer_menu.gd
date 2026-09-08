extends Control
# O lobby. Este menu É a sala de espera: o host fica aqui, com o código na
# tela, até o oponente conectar de verdade. Entrar na arena antes disso deixaria
# um duelo contra ninguém e ainda faria o host resolver acertos num mundo que o
# cliente ainda não carregou.

@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var room_code_edit: LineEdit = $VBox/RoomCodeEdit
@onready var confirm_button: Button = $VBox/ConfirmButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var back_button: Button = $VBox/BackButton

var _pending_action: String = ""
var _hosting_and_waiting: bool = false
# Guarda contra dupla troca de cena: peer_connected e connection_succeeded
# nunca devem os dois avançar, mas um empate silencioso aqui é impossível de
# depurar depois.
var _advancing: bool = false

func _ready() -> void:
	# Sessão anterior pode ter deixado peer/socket vivos.
	GameManager.leave_session()

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	room_code_edit.text_submitted.connect(func(_t: String): _on_confirm_pressed())
	back_button.pressed.connect(_on_back_pressed)

	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	OnlineNetworkManager.room_created.connect(_on_room_created)
	OnlineNetworkManager.joined_room.connect(_on_joined_room)
	OnlineNetworkManager.connection_failed.connect(_on_online_connection_failed)

	room_code_edit.text = GameManager.last_room_code
	_show_code_input(false)
	status_label.text = ""
	host_button.grab_focus()

func _show_code_input(visible_now: bool) -> void:
	room_code_edit.visible = visible_now
	confirm_button.visible = visible_now

func _set_busy(busy: bool) -> void:
	host_button.disabled = busy
	join_button.disabled = busy
	confirm_button.disabled = busy
	room_code_edit.editable = not busy

# ---------- ações do jogador ----------

func _on_host_pressed() -> void:
	_pending_action = "host"
	_show_code_input(true)
	status_label.text = "Escolha um código e confirme."
	room_code_edit.grab_focus()

func _on_join_pressed() -> void:
	_pending_action = "join"
	_show_code_input(true)
	status_label.text = "Digite o código do host e confirme."
	room_code_edit.grab_focus()

func _on_confirm_pressed() -> void:
	if _pending_action == "" or confirm_button.disabled:
		return

	var room := room_code_edit.text.strip_edges()
	if room == "":
		room = "sala1"
	GameManager.last_room_code = room

	_set_busy(true)

	if _pending_action == "host":
		# O primeiro connect da sessão pode demorar: o servidor de sinalização
		# roda no free tier do Render e faz cold start.
		status_label.text = "Criando sala '%s'...\n(o servidor pode levar até 1 min para acordar)" % room
		_hosting_and_waiting = true
		OnlineNetworkManager.host_online(room)
	else:
		status_label.text = "Entrando na sala '%s'...\n(o servidor pode levar até 1 min para acordar)" % room
		OnlineNetworkManager.join_online(room)

func _on_back_pressed() -> void:
	GameManager.leave_session()
	get_tree().change_scene_to_file(GameManager.MAIN_MENU_SCENE)

# ---------- sinalização ----------

func _on_room_created(room: String) -> void:
	status_label.text = "Sala '%s' criada.\nAguardando o oponente..." % room

func _on_joined_room(room: String) -> void:
	status_label.text = "Na sala '%s'.\nNegociando conexão P2P..." % room

func _on_online_connection_failed(reason: String) -> void:
	_hosting_and_waiting = false
	_set_busy(false)
	status_label.text = reason

func _on_connection_failed() -> void:
	_hosting_and_waiting = false
	_set_busy(false)
	status_label.text = "Falha na conexão."

# ---------- entrada na arena ----------

# Caminho do HOST: ele avança quando o oponente realmente conecta.
func _on_peer_connected(_id: int) -> void:
	if not _hosting_and_waiting:
		return
	_hosting_and_waiting = false
	_advance_to_arena()

# Caminho do CLIENTE: connected_to_server. O host NÃO usa este sinal, senão os
# dois disputariam a troca de cena.
func _on_connection_succeeded() -> void:
	_advance_to_arena()

func _advance_to_arena() -> void:
	if _advancing:
		return
	_advancing = true
	status_label.text = "Conectado! Entrando na arena..."
	get_tree().change_scene_to_file(GameManager.PVP_ARENA_SCENE)
