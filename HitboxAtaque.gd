class_name HitboxAtaque
extends Area3D

var dano: float = 0.0
var tiempo_aturdimiento: float = 0.0
var emisor: Node3D = null
var arma_ref: ArmaResource = null
var tiempo_vida: float = 0.15
var tiempo_actual: float = 0.0

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	tiempo_actual += delta
	if tiempo_actual >= tiempo_vida:
		queue_free()
		return

	if emisor != null and is_instance_valid(emisor) and arma_ref != null:
		# Posición frontal fluida respecto al jugador
		var objetivo_pos = emisor.global_position + (-emisor.transform.basis.z * arma_ref.alcance_distancia)
		global_position = global_position.lerp(objetivo_pos, delta * 25.0)
		
		# Sincronizar al instante la rotación horizontal del emisor (jugador) sin alterar alturas
		rotation.y = emisor.rotation.y

func _on_body_entered(cuerpo: Node3D) -> void:
	if cuerpo == emisor:
		return

	if cuerpo is Enemigo or cuerpo.has_method("take_damage") or cuerpo.has_method("recibir_dano"):
		if cuerpo.has_method("take_damage"):
			cuerpo.take_damage(dano)
		elif cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano)
			
		if cuerpo.has_method("aplicar_aturdimiento"):
			cuerpo.aplicar_aturdimiento(tiempo_aturdimiento)
