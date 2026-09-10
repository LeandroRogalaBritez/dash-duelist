extends Combatant
class_name Player

# MODELO DE CONFIANÇA (decisão consciente, não descuido):
# cada peer é autoritativo sobre o timing do PRÓPRIO dash — é isso que compra
# um dash sem lag de input — e o host é autoritativo sobre TODO o HP. Um
# cliente malicioso poderia manter dash_active sempre true e ficar imortal.
# Para um duelo entre amigos é a troca certa.

@export var normal_velocity: int = 192
@export var max_hp: int = 100

# 0 == offline. Sentinela deliberada (o project-adventure usa 1): assim a arena
# de um jogador nunca toca a MultiplayerAPI, e player.tscn continua drop-in em
# qualquer cena sem rede.
@export var owner_peer_id: int = 0

@onready var sound_bank: SoundBank = $SoundBank
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var state_machine: StateMachine = $StateMachine
@onready var cooldown_bar: FloatingBar = $CooldownDash

signal dash_cooldown_change(progress: float)
signal health_changed(current_hp: int)
signal died

# Janela em que o host ignora acertos novos na mesma vítima. Aproxima a
# animação de hurt (0,4 s) + os 40 frames de i-frames (0,667 s).
const SERVER_HIT_LOCKOUT_MS := 1000

var is_dead: bool = false
# last_direction guarda a última direção NÃO-zero (é dela que o dash sai);
# input_dir é a direção deste frame, e é ela que decide Idle vs Walk.
var last_direction := Vector2.DOWN
var input_dir := Vector2.ZERO
var dash_open := true
# Inicializado a partir de max_hp no _ready, e não aqui: os valores de @export
# vindos da cena só são aplicados DEPOIS dos inicializadores de membro, então
# `var hp := max_hp` ignoraria um max_hp sobrescrito na .tscn.
var hp: int = 100
# dash_active substitui o trio dash_iframes_active + hitbox.monitoring +
# hitbox.monitorable, que sempre ligavam e desligavam juntos. Sendo um único
# campo, é replicável — e é justamente ele que faz o dash do cliente existir
# na máquina do host.
var dash_active: bool = false
var damage_iframes_active: bool = false
# Replicados junto com a posição, para a réplica saber o que desenhar.
var facing_left: bool = false
var anim_name: StringName = &"idle"
var dash_progress: float = 100.0
# Em PVP o host congela os dois players até o cliente reportar arena carregada,
# e de novo quando o duelo termina.
var round_active: bool = true

var _server_lockout_until_ms: int = 0

func _ready() -> void:
	hp = max_hp
	cooldown_bar.value = dash_progress

func _physics_process(_delta: float) -> void:
	_apply_dash_active()
	cooldown_bar.value = dash_progress
	if is_networked() and not is_local():
		_sync_visuals()

# Idempotente. Só monitorable importa: quem detecta o acerto é o Hurtbox do
# alvo (que tem player_hitbox no mask), não o nosso Hitbox. Rodar isso em TODO
# peer é o que arma o hitbox da réplica na máquina do host.
func _apply_dash_active() -> void:
	hitbox.monitorable = dash_active

func is_invulnerable() -> bool:
	return dash_active or damage_iframes_active

# ---------- identidade de rede ----------

func is_networked() -> bool:
	return owner_peer_id != 0

func is_local() -> bool:
	# Curto-circuito antes de tocar em multiplayer: offline nunca chama
	# get_unique_id().
	return owner_peer_id == 0 or owner_peer_id == multiplayer.get_unique_id()

# Chamado pela pvp_arena depois que ela mesma está pronta. Deixa a ordem
# explícita em vez de depender das sutilezas de _enter_tree/_ready.
func net_init(peer_id: int) -> void:
	owner_peer_id = peer_id
	_setup_replication()
	# DEPOIS de criar o synchronizer, e recursivo: add_child() não propaga
	# autoridade, então um synchronizer criado após esta chamada ficaria em
	# authority 1 e simplesmente não enviaria nada do cliente.
	set_multiplayer_authority(owner_peer_id)
	if not is_local():
		# Réplica: só visual. Sem isso ela rodaria a própria state machine, leria
		# o teclado local e brigaria com o synchronizer pela posição.
		state_machine.set_physics_process(false)

func _setup_replication() -> void:
	var config := SceneReplicationConfig.new()
	_replicate(config, ".:global_position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_replicate(config, ".:anim_name", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_replicate(config, ".:facing_left", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_replicate(config, ".:dash_active", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_replicate(config, ".:dash_progress", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	sync.replication_config = config
	add_child(sync)

func _replicate(config: SceneReplicationConfig, prop: String, mode: int) -> void:
	var path := NodePath(prop)
	config.add_property(path)
	config.property_set_replication_mode(path, mode)

# O synchronizer replica o CAMPO, não a chamada sprite.play(). Sem isto a
# réplica ficaria congelada num único frame.
func _sync_visuals() -> void:
	sprite.flip_h = facing_left
	if sprite.animation != anim_name:
		sprite.play(anim_name)

# ---------- animação, som, input ----------

func play_anim(name: StringName) -> void:
	anim_name = name
	sprite.play(name)

# SoundManager é autoload, então sem este relay as ações do oponente seriam
# completamente mudas.
func play_sfx(name: String, volume_db: float = 0.0) -> void:
	if not is_networked():
		sound_bank.playSfx(name, volume_db)
		return
	if not is_local():
		# Réplica: o dono transmite o som por net_play_sfx; tocar aqui também
		# duplicaria, e um .rpc() daqui seria rejeitado (não somos authority).
		return
	net_play_sfx.rpc(name, volume_db)

@rpc("authority", "call_local", "reliable")
func net_play_sfx(name: String, volume_db: float) -> void:
	sound_bank.playSfx(name, volume_db)

func wants_dash() -> bool:
	return is_local() and round_active and dash_open and Input.is_action_just_pressed("dash")

func move_with_input() -> void:
	if not is_local():
		return
	if not round_active:
		input_dir = Vector2.ZERO
		velocity = Vector2.ZERO
		return

	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * normal_velocity
	move_and_slide()

	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()

	if input_dir.x != 0:
		facing_left = input_dir.x < 0
		sprite.flip_h = facing_left

func set_dash_progress(progress: float) -> void:
	dash_progress = progress
	dash_cooldown_change.emit(progress)

# ---------- dano ----------

# Ponto de entrada único do Hurtbox. É aqui que vive a divisão de autoridade.
func on_hurtbox_hit(other: Node, amount: int) -> void:
	if not is_networked():
		if is_invulnerable():
			return
		take_damage(amount)
		return

	# Em rede os DOIS peers detectam a sobreposição localmente, em frames
	# ligeiramente diferentes. O cliente descarta a própria detecção: é isso
	# que garante exatamente uma decisão autoritativa por acerto.
	if not multiplayer.is_server():
		return

	_server_resolve_hit(other, amount)

func _server_resolve_hit(_other: Node, amount: int) -> void:
	if is_dead or hp <= 0 or not round_active:
		return
	# dash_active é replicado, então o host sabe quando a vítima está esquivando.
	if dash_active:
		return
	# Relógio do próprio host, e não damage_iframes_active replicado: o valor do
	# cliente chegaria 1 RTT atrasado (abrindo janela para um segundo acerto) e
	# faria o host confiar no stun declarado pelo cliente.
	var now := Time.get_ticks_msec()
	if now < _server_lockout_until_ms:
		return
	_server_lockout_until_ms = now + SERVER_HIT_LOCKOUT_MS
	net_apply_damage.rpc(maxi(hp - amount, 0))

# "any_peer", e não "authority": a autoridade DESTE nó é o dono do personagem,
# não o host — e é o host que manda o dano. Então o filtro é explícito.
# Sendo call_local + reliable, host e cliente entram em Hurt no mesmo pacote,
# o que é o que mantém stun e i-frames iguais nos dois lados.
@rpc("any_peer", "call_local", "reliable")
func net_apply_damage(new_hp: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return

	hp = new_hp
	health_changed.emit(hp)

	if hp <= 0:
		die()
	else:
		state_machine.hurt()

# Cura entre ondas do single player. Chamada só pelo arena.gd; o PVP tem vida
# única e nunca cura.
func heal(amount: int) -> void:
	if is_dead or hp >= max_hp:
		return
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp)

func take_damage(amount: int) -> void:
	# Em PVP o HP é decidido pelo host e propagado por net_apply_damage; nada
	# deve mexer em hp por este caminho.
	if is_networked():
		return

	if is_invulnerable():
		return

	hp -= amount
	health_changed.emit(hp)

	if hp <= 0:
		die()
		return

	state_machine.hurt()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	# Sem isso, um player morto no meio do dash deixa um hitbox letal no cadáver.
	dash_active = false
	# set_deferred, e não atribuição direta: die() é chamado de dentro do
	# area_entered/body_entered do Hurtbox, e o Godot BLOQUEIA mexer em
	# monitoring durante a emissão do próprio sinal ("Function blocked during
	# in/out signal") — a atribuição direta era silenciosamente descartada e o
	# cadáver continuava recebendo dano.
	hurtbox.set_deferred("monitoring", false)
	state_machine.die()
