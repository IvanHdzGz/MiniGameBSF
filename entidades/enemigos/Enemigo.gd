class_name Enemigo
extends CharacterBody3D

enum RangoEnemigo { NORMAL, ELITE, JEFE }

@export_group("Tipo de Enemigo")
@export var rango: RangoEnemigo = RangoEnemigo.NORMAL

@export_group("Estadísticas Base")
@export var salud_maxima: float = 30.0
@export var dano_ataque: float = 10.0
@export var velocidad_movimiento: float = 3.5
@export var cooldown_ataque: float = 1.0

# Agregar en las variables superiores de EnemigoBase.gd:
var ruido_movimiento := FastNoiseLite.new()
var tiempo_existencia: float = 0.0
@export var fuerza_erratica: float = 0.6 # Controla qué tanto se desvía (0.0 = línea recta, 1.0 = muy errático)

var salud_actual: float
var jugador: Node3D = null
var ultimo_golpe_tiempo: int = 0
var esta_aturdido: bool = false

@onready var area_ataque: Area3D = $AreaAtaque if has_node("AreaAtaque") else null
@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null

func _ready() -> void:
	_aplicar_modificadores_rango()
	
	# Configuración del ruido único por enemigo
	ruido_movimiento.seed = randi()
	ruido_movimiento.frequency = 0.8
	
	var nodos_jugador = get_tree().get_nodes_in_group("Jugador")
	if nodos_jugador.size() > 0:
		jugador = nodos_jugador[0]

	if health_component:
		health_component.max_health = salud_maxima
		health_component.current_health = salud_maxima
		if not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)
	else:
		salud_actual = salud_maxima

	if area_ataque and not area_ataque.body_entered.is_connected(_on_area_ataque_body_entered):
		area_ataque.body_entered.connect(_on_area_ataque_body_entered)

func _physics_process(delta: float) -> void:
	tiempo_existencia += delta
	
	if jugador != null and is_instance_valid(jugador):
		# 1. Dirección base hacia el jugador
		var dir_base = (jugador.global_position - global_position).normalized()
		
		# 2. Calcular desviación lateral con ruido
		var desviacion_x = ruido_movimiento.get_noise_1d(tiempo_existencia * 2.0)
		var desviacion_z = ruido_movimiento.get_noise_1d((tiempo_existencia + 100.0) * 2.0)
		
		var vector_desviacion = Vector3(desviacion_x, 0.0, desviacion_z) * fuerza_erratica
		var direccion_final = (dir_base + vector_desviacion).normalized()
		direccion_final.y = 0.0
		
		velocity = direccion_final * velocidad_movimiento
		
		# Orientar la visual del enemigo suavemente hacia donde camina
		if velocity.length_squared() > 0.01:
			var target_rot = atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, target_rot, delta * 8.0)
			
		move_and_slide()

	if area_ataque and area_ataque.has_overlapping_bodies():
		for body in area_ataque.get_overlapping_bodies():
			intentar_aplicar_dano(body)

func _on_area_ataque_body_entered(body: Node3D) -> void:
	intentar_aplicar_dano(body)

func intentar_aplicar_dano(body: Node3D) -> void:
	if body.is_in_group("Jugador") or body.name == "Jugador":
		# Si el jugador es invulnerable (está haciendo dash), ignoramos el daño por completo
		if "es_invulnerable" in body and body.es_invulnerable:
			return

		var tiempo_actual = Time.get_ticks_msec()
		if tiempo_actual - ultimo_golpe_tiempo >= int(cooldown_ataque * 1000):
			if body.has_method("recibir_dano"):
				ultimo_golpe_tiempo = tiempo_actual
				body.recibir_dano(dano_ataque)
## Recibir daño desde el jugador (soporta HealthComponent o directo)
func take_damage(amount: float) -> void:
	if health_component:
		health_component.take_damage(amount)
	else:
		recibir_dano(amount)

func recibir_dano(cantidad: float) -> void:
	salud_actual = max(0.0, salud_actual - cantidad)
	if salud_actual <= 0.0:
		morir()

func aplicar_aturdimiento(tiempo: float) -> void:
	if tiempo <= 0.0 or esta_aturdido:
		return
		
	esta_aturdido = true
	var velocidad_previa = velocidad_movimiento
	velocidad_movimiento = 0.0 # Congela el movimiento durante el stun
	
	get_tree().create_timer(tiempo).timeout.connect(func():
		velocidad_movimiento = velocidad_previa
		esta_aturdido = false
	)

func _on_health_depleted() -> void:
	morir()

func morir() -> void:
	queue_free()

## Ajusta automáticamente vida, daño y escala según la variante
func _aplicar_modificadores_rango() -> void:
	match rango:
		RangoEnemigo.NORMAL:
			pass
		RangoEnemigo.ELITE:
			salud_maxima *= 2.0
			dano_ataque *= 1.5
			scale *= 1.3
			_aplicar_efecto_visual_elite()
		RangoEnemigo.JEFE:
			salud_maxima *= 5.0
			dano_ataque *= 2.0
			scale *= 2.2

func _aplicar_efecto_visual_elite() -> void:
	var mesh = $MeshInstance3D if has_node("MeshInstance3D") else null
	if mesh and mesh.get_active_material(0):
		var mat = mesh.get_active_material(0).duplicate()
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(1.0, 0.4, 0.1)
			mesh.set_surface_override_material(0, mat)
