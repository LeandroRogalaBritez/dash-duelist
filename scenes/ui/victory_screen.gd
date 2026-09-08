extends CanvasLayer
# Instanciada escondida DENTRO da arena, em vez de ser uma cena própria: a
# arena continua visível atrás (fica mais bonito) e evita um segundo
# change_scene_to_file correndo com o teardown do peer.

const COLOR_WIN := Color(0.98, 0.89, 0.56)
const COLOR_LOSE := Color(0.86, 0.44, 0.44)

@onready var root: Control = $Root
@onready var title: Label = $Root/VBox/Title
@onready var reason: Label = $Root/VBox/Reason
@onready var back_button: Button = $Root/VBox/BackButton

func _ready() -> void:
	root.visible = false
	back_button.pressed.connect(_on_back_pressed)

# Fim de duelo PVP.
func show_result(won: bool, reason_text: String = "") -> void:
	_show(
		"Você venceu!" if won else "Você perdeu",
		COLOR_WIN if won else COLOR_LOSE,
		reason_text,
	)

# Fim de run do single player.
func show_game_over(wave: int) -> void:
	_show("Game Over", COLOR_LOSE, "Você perdeu na onda %d" % wave)

func _show(title_text: String, color: Color, reason_text: String) -> void:
	title.text = title_text
	title.modulate = color
	reason.text = reason_text
	root.visible = true
	back_button.grab_focus()

func _on_back_pressed() -> void:
	GameManager.leave_session_and_go_to_menu()
