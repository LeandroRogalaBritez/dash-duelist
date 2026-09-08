extends Area2D
class_name Hitbox

# Marcador puro. Quem detecta o acerto é sempre o Hurtbox do alvo (que tem
# player_hitbox no mask); este nó só precisa ficar monitorable durante o dash.
#
# O handler antigo ("chame die() em qualquer coisa que eu tocar") era código
# morto — o mask nunca alcançava um nó com die() — e foi removido de propósito:
# com o mask do Hurtbox do player agora incluindo player_hitbox, ele viraria
# uma mina que mata o oponente instantaneamente, furando HP e autoridade.

func _ready() -> void:
	monitoring = false
