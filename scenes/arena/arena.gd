extends Node2D
# Controlador da run single player: ondas de inimigos, cura entre ondas e game
# over. O loop mora aqui, e não num nó WaveSpawner separado, porque os inimigos
# TÊM de ser filhos diretos desta Arena — enemy.gd faz `player = $"../Player"`
# e shoot() adiciona o projétil em get_parent(). Um spawner separado precisaria
# de um spawn_root exportado apontando para o próprio pai, indireção sem ganho.

@export var enemy_scene: PackedScene

# Balanceamento, tudo num lugar só.
const BASE_ENEMIES := 2           # onda 1
const EXTRA_PER_WAVE := 1         # 2, 3, 4, 5...
const HEAL_PER_WAVE := 20
const WAVE_BREAK_SECONDS := 1.5
const SPAWN_JITTER := 24.0        # px de variação em cima do marcador
const MIN_SPAWN_DISTANCE := 200.0 # nunca nascer no colo do player
# Maior que a diagonal da arena (~1310 px) de propósito: num loop de ondas a
# horda tem de vir até o player. Os inimigos colocados à mão usavam 400 porque
# eram emboscadas paradas — com os spawns nas bordas, 400 deixaria 6 dos 8
# pontos fora do alcance e as ondas virariam uma caçada.
const ENEMY_DETECTION_RANGE := 2000.0
const ENEMY_ATTACK_RANGE := 250.0

@onready var sound_bank: SoundBank = $SoundBank
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $Hud
@onready var victory_screen: CanvasLayer = $VictoryScreen

var _wave: int = 0
var _wave_enemies: Array[Enemy] = []
var _run_over: bool = false

func _ready() -> void:
	player.health_changed.connect(hud._on_health_change)
	player.died.connect(_on_player_died)
	sound_bank.playMusic("background", -30.0)
	_start_wave(1)

# ---------- ondas ----------

func _start_wave(wave: int) -> void:
	_wave = wave
	var count := BASE_ENEMIES + (wave - 1) * EXTRA_PER_WAVE

	hud.set_wave(wave)
	hud.set_enemies_left(count)
	hud.announce("Onda %d" % wave)

	# Ordem embaralhada por onda: com mais inimigos que marcadores as ondas
	# altas reusam pontos, e sem o shuffle sempre reusariam os mesmos primeiros.
	var markers := $SpawnPoints.get_children()
	markers.shuffle()

	for i in count:
		_spawn_enemy(markers, i)

func _spawn_enemy(markers: Array, index: int) -> void:
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.detection_range = ENEMY_DETECTION_RANGE
	enemy.attack_range = ENEMY_ATTACK_RANGE
	enemy.position = _pick_spawn_position(markers, index)

	# Filho direto da Arena: é o que faz o `$"../Player"` do enemy.gd resolver.
	add_child(enemy)

	# health_changed com hp <= 0, e não o sinal `died`: `died` só é emitido
	# depois do await da animação de morte (~1,3 s), o que faria o contador da
	# HUD atrasar em cada abate. take_damage() emite health_changed exatamente
	# uma vez com hp <= 0, porque is_dying barra as chamadas seguintes.
	enemy.health_changed.connect(_on_enemy_health_changed.bind(enemy))
	_wave_enemies.append(enemy)

func _pick_spawn_position(markers: Array, index: int) -> Vector2:
	if markers.is_empty():
		return global_position

	# Tenta cada marcador a partir do que caberia neste índice, e fica no
	# primeiro que não estiver perto do player.
	for attempt in markers.size():
		var marker: Node2D = markers[(index + attempt) % markers.size()]
		var candidate: Vector2 = marker.position + Vector2(
			randf_range(-SPAWN_JITTER, SPAWN_JITTER),
			randf_range(-SPAWN_JITTER, SPAWN_JITTER),
		)
		if candidate.distance_to(player.position) >= MIN_SPAWN_DISTANCE:
			return candidate

	# Todos perto do player (não acontece com o mapa atual, mas não vale travar
	# a onda por isso): usa o marcador mais distante que existir.
	var farthest: Node2D = markers[0]
	for marker in markers:
		if marker.position.distance_to(player.position) > farthest.position.distance_to(player.position):
			farthest = marker
	return farthest.position

func _on_enemy_health_changed(hp: int, enemy: Enemy) -> void:
	if hp > 0:
		return

	_wave_enemies.erase(enemy)
	hud.set_enemies_left(_wave_enemies.size())

	if _wave_enemies.is_empty():
		_finish_wave()

func _finish_wave() -> void:
	if _run_over:
		return

	player.heal(HEAL_PER_WAVE)
	hud.announce("Onda %d limpa!" % _wave, WAVE_BREAK_SECONDS)

	# As animações de morte (~1,3 s) rodam dentro desta pausa, então os corpos
	# já sumiram quando a onda seguinte nasce.
	await get_tree().create_timer(WAVE_BREAK_SECONDS).timeout

	# Recheca: o player pode ter morrido durante a pausa (projétil em voo).
	if _run_over:
		return

	_start_wave(_wave + 1)

# ---------- game over ----------

func _on_player_died() -> void:
	if _run_over:
		return
	_run_over = true

	for enemy in _wave_enemies:
		if is_instance_valid(enemy):
			enemy.state_machine.set_physics_process(false)

	# As flechas em voo são filhas da Arena (enemy.gd faz
	# get_parent().add_child), não do inimigo que atirou.
	for child in get_children():
		if child is Projectile:
			child.queue_free()

	victory_screen.show_game_over(_wave)
