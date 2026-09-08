extends Control

func _ready() -> void:
	# Chegar aqui significa que nenhuma partida está em andamento. Se voltamos
	# de um duelo, isto garante que não sobrou peer nem socket de sinalização
	# aberto — é o que permite hospedar uma segunda partida no mesmo processo.
	GameManager.leave_session()

	$VBox/SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$VBox/MultiplayerButton.pressed.connect(_on_multiplayer_pressed)
	$VBox/QuitButton.pressed.connect(_on_quit_pressed)
	$VBox/SinglePlayerButton.grab_focus()

func _on_single_player_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.ARENA_SCENE)

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.MULTIPLAYER_MENU_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
