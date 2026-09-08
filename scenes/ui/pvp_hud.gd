extends CanvasLayer

@onready var local_health: ProgressBar = $LocalBox/Health
@onready var remote_health: ProgressBar = $RemoteBox/Health
@onready var status_label: Label = $StatusLabel

func bind(local_player: Player, remote_player: Player) -> void:
	local_health.max_value = local_player.max_hp
	local_health.value = local_player.hp
	remote_health.max_value = remote_player.max_hp
	remote_health.value = remote_player.hp

	local_player.health_changed.connect(func(value: int) -> void: local_health.value = value)
	remote_player.health_changed.connect(func(value: int) -> void: remote_health.value = value)

func set_status(text: String) -> void:
	status_label.text = text
