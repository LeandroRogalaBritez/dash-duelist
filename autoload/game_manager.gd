extends Node
# autoload/game_manager.gd (autoload: GameManager)
#
# Coordenador de nível de jogo: paths de cena, id local e o teardown de sessão.
# Não conhece transporte nem regras de combate.

const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const MULTIPLAYER_MENU_SCENE := "res://scenes/menu/multiplayer_menu.tscn"
const ARENA_SCENE := "res://scenes/arena/arena.tscn"
const PVP_ARENA_SCENE := "res://scenes/pvp_arena/pvp_arena.tscn"

# Último código de sala digitado, para reexibir no menu multiplayer.
var last_room_code: String = ""

func local_id() -> int:
	return multiplayer.get_unique_id()

# Encerra a sessão de rede por completo: o peer de jogo E o socket de
# sinalização. Ponto único de teardown — usado pela tela de vitória, pelos
# tratadores de desconexão e pelo botão de voltar do menu multiplayer.
func leave_session() -> void:
	OnlineNetworkManager.close_signaling()
	NetworkManager.stop()

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func leave_session_and_go_to_menu() -> void:
	# Troca de cena PRIMEIRO, e o teardown de rede vem depois, no _ready do
	# menu. Fechar o peer com a arena ainda viva faz os MultiplayerSynchronizer
	# dela tentarem enviar num canal já fechado (erro
	# `Condition "channel->isClosed()" is true`).
	#
	# Deferido porque isto costuma ser chamado de dentro de um handler de sinal
	# do MultiplayerAPI, e trocar de cena ali derruba nós que ainda estão sendo
	# percorridos.
	call_deferred("go_to_main_menu")
