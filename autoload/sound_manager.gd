extends Node

const POOL_SIZE := 8

var pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _next_free_sfx_player()
	player.volume_db = volume_db
	player.stream = stream
	player.play()

# Se não tem nenhum livre, utiliza o primeiro cortando o som atual se estiver executando.
func _next_free_sfx_player() -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()

func stop_music() -> void:
	music_player.stop()
