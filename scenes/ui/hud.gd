extends CanvasLayer

@onready var health: ProgressBar = $Heath
@onready var wave_label: Label = $WaveLabel
@onready var enemies_label: Label = $EnemiesLabel
@onready var announce_label: Label = $AnnounceLabel

# Cada announce() pega um token novo. Só quem ainda for o token corrente limpa o
# texto no fim da espera — senão o "Onda 1 limpa!" apagaria o "Onda 2" que veio
# depois dele.
var _announce_token: int = 0

func _ready() -> void:
	announce_label.text = ""

func _on_health_change(_health: float) -> void:
	health.value = _health

func set_wave(wave: int) -> void:
	wave_label.text = "Onda %d" % wave

func set_enemies_left(count: int) -> void:
	enemies_label.text = "Inimigos: %d" % count

func announce(text: String, seconds: float = 1.5) -> void:
	_announce_token += 1
	var token := _announce_token
	announce_label.text = text
	await get_tree().create_timer(seconds).timeout
	if token == _announce_token:
		announce_label.text = ""
