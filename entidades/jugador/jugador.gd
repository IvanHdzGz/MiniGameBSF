extends CharacterBody3D

# --- ESTADÍSTICAS ---
@export var salud_maxima: float = 100.0
var salud_actual: float = 100.0

@export_group("Estamina y Movimiento")
@export var estamina_maxima: float = 100.0
@export var consumo_sprint: float = 20.0 # Por segundo
@export var consumo_dash: float = 30.0
@export var consumo_ataque: float = 0.0
@export var regeneracion_estamina: float = 20.0 # Por segundo
@export var tiempo_espera_regeneracion: float = 1.0 # Retardo tras consumo (1 a 1.5s)

# Variable de control para la velocidad de ataque en el jugador
var multiplicador_velocidad_ataque: float = 1.0

# En las variables de Jugador.gd:
@export_group("Equipamiento")
@export var arma_equipada: ArmaResource # Asigna un recurso .tres en el Inspector

var estamina_actual: float = 100.0
var agotado: bool = false # Estado de penalización si llega a 0%
var tiempo_sin_usar_estamina: float = 0.0

# --- MOVIMIENTO ---
const WALK_SPEED: float = 6.0
const SPRINT_SPEED: float = 10.0
const DASH_BASE_SPEED: float = 18.0
const DASH_SPRINT_SPEED: float = 24.0

# Supongamos que tu capa de enemigos es la 3 (valor binario 4, o usando máscaras directamente)
const MASCARA_CON_ENEMIGOS: int = 0xFFFFFFFF # O tu máscara habitual que incluye enemigos
const MASCARA_SIN_ENEMIGOS: int = 0xFFFFFFFD # Ejemplo: desactiva el bit de la capa 3 si usas máscaras personalizadas

const DASH_DURATION: float = 0.22
const ATAQUE_COOLDOWN: float = 1

var is_dashing: bool = false
var is_invulnerable: bool = false
var puede_atacar: bool = true

var current_dash_speed: float = DASH_BASE_SPEED
var escena_ataque: PackedScene = preload("res://entidades/jugador/Ataque_Prototipo.tscn")

@onready var camara: Camera3D = get_viewport().get_camera_3d()
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	salud_actual = salud_maxima
	estamina_actual = estamina_maxima
	actualizar_hud()

func _process(delta: float) -> void:
	_manejar_regeneracion_estamina(delta)

func _manejar_regeneracion_estamina(delta: float) -> void:
	# Contabilizar tiempo sin consumir estamina
	tiempo_sin_usar_estamina += delta

	# Solo regenerar si ya transcurrió el tiempo de espera
	if tiempo_sin_usar_estamina >= tiempo_espera_regeneracion:
		if estamina_actual < estamina_maxima:
			estamina_actual = min(estamina_actual + regeneracion_estamina * delta, estamina_maxima)
			
			# Levantar penalización de agotamiento cuando supere el 25%
			if agotado and estamina_actual >= (estamina_maxima * 0.25):
				agotado = false

func consumir_estamina(cantidad: float) -> bool:
	# Si está en estado de agotamiento, bloquea la acción
	if agotado:
		return false

	if estamina_actual >= cantidad:
		estamina_actual -= cantidad
		tiempo_sin_usar_estamina = 0.0 # Reinicia retardo de regeneración (1.2s)
		
		# Si llega exactamente a 0, entra en agotamiento obligatorio
		if estamina_actual <= 0.0:
			estamina_actual = 0.0
			agotado = true
		return true
	else:
		# Si la estamina era insuficiente para la acción completa, entra en agotamiento
		estamina_actual = 0.0
		agotado = true
		tiempo_sin_usar_estamina = 0.0
		return false

func intentar_sprint(delta: float) -> bool:
	if agotado or estamina_actual <= 0.0:
		return false
	
	estamina_actual -= consumo_sprint * delta
	tiempo_sin_usar_estamina = 0.0
	
	if estamina_actual <= 0.0:
		estamina_actual = 0.0
		agotado = true # Se apaga el sprint automáticamente
		return false
		
	return true

func intentar_dash() -> bool:
	return consumir_estamina(consumo_dash)

func intentar_ataque() -> bool:
	return consumir_estamina(consumo_ataque)

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	apuntar_al_raton()

	# --- MANEJO DE SPRINT ---
	var wants_to_sprint := Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	var is_sprinting := false

	if wants_to_sprint:
		is_sprinting = intentar_sprint(delta)

	# --- MANEJO DE DASH ---
	if Input.is_action_just_pressed("ui_accept") and not is_dashing and direction != Vector3.ZERO:
		if intentar_dash():
			ejecutar_dash(is_sprinting)

	# --- MANEJO DE ATAQUE ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and puede_atacar and not is_dashing:
		if intentar_ataque():
			atacar()

	# --- CÁLCULO DE VELOCIDAD DE MOVIMIENTO ---
	var target_speed: float
	if is_dashing:
		target_speed = current_dash_speed
	elif is_sprinting:
		target_speed = SPRINT_SPEED
	else:
		target_speed = WALK_SPEED

	# Aplicamos el multiplicador de ataque aquí para que frene al golpear
	var velocidad_final = target_speed * multiplicador_velocidad_ataque

	if direction != Vector3.ZERO:
		velocity.x = direction.x * velocidad_final
		velocity.z = direction.z * velocidad_final
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_final)
		velocity.z = move_toward(velocity.z, 0, velocidad_final)

	# Un solo 'move_and_slide' y un solo 'actualizar_hud' al final
	move_and_slide()
	actualizar_hud()

func ejecutar_dash(is_sprinting: bool) -> void:
	is_dashing = true
	is_invulnerable = true # Activamos la invulnerabilidad para que el daño de enemigos sea ignorado
	
	# Desactivar temporalmente la capa física del jugador para que los enemigos lo atraviesen por completo
	# (Asumiendo que tu jugador está en la Capa 2, ajusta el número si está en otra)
	set_collision_layer_value(2, false)
	set_collision_mask_value(3, false) # Desactiva colisión con capa de enemigos
	
	# Determinar velocidad de dash
	current_dash_speed = DASH_SPRINT_SPEED if is_sprinting else DASH_BASE_SPEED
	
	# Duración del dash (ej. 0.2 segundos)
	var duracion_dash = 0.2
	
	get_tree().create_timer(duracion_dash).timeout.connect(func():
		is_dashing = false
		is_invulnerable = false # Desactivamos la invulnerabilidad al terminar
		
		# Restaurar capas y máscaras originales del jugador
		set_collision_layer_value(2, true)
		set_collision_mask_value(3, true)
	)

func atacar() -> void:
	if arma_equipada == null or not puede_atacar:
		return

	var costo_estamina: float = arma_equipada.consumo_estamina

	if estamina_actual <= 0.0:
		return

	estamina_actual = max(0.0, estamina_actual - costo_estamina)
	puede_atacar = false
	
	# Reducir velocidad de movimiento durante el ataque (ej. al 30% de su velocidad normal)
	multiplicador_velocidad_ataque = .65

	# Cooldown del ataque y restablecer velocidad al terminar
	get_tree().create_timer(arma_equipada.cooldown_ataque).timeout.connect(func(): 
		puede_atacar = true
		multiplicador_velocidad_ataque = 1.0
	)

	# 1. Crear e instanciar la Hitbox de manera limpia
	var hitbox := HitboxAtaque.new()
	var colision := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	
	forma.size = arma_equipada.tamano_hitbox
	colision.shape = forma
	hitbox.add_child(colision)
	
	hitbox.dano = arma_equipada.dano
	hitbox.tiempo_aturdimiento = arma_equipada.tiempo_aturdimiento
	hitbox.emisor = self
	hitbox.arma_ref = arma_equipada
	
	# Copiar exactamente la posición y orientación actual del jugador (que ya sigue el ratón)
	hitbox.global_transform = global_transform
	# Desplazarla hacia adelante según el alcance del arma
	hitbox.global_position = global_position + (-transform.basis.z * arma_equipada.alcance_distancia)

	hitbox.collision_layer = 0
	hitbox.collision_mask = 0xFFFFFFFF

	get_parent().add_child(hitbox)

func recibir_dano(cantidad: float) -> void:
	if is_invulnerable:
		return
		
	salud_actual = max(0.0, salud_actual - cantidad)
	actualizar_hud()
	
	# Ventana de invulnerabilidad corta tras ser golpeado
	is_invulnerable = true
	get_tree().create_timer(0.1).timeout.connect(func(): is_invulnerable = false)

func actualizar_hud() -> void:
	if hud and hud.has_method("actualizar_salud"):
		hud.actualizar_salud(salud_actual, salud_maxima)
		hud.actualizar_estamina(estamina_actual, estamina_maxima)

func apuntar_al_raton() -> void:
	var camara = get_viewport().get_camera_3d()
	# Verificamos que la cámara exista y esté dentro del árbol de escenas activo
	if camara == null or not camara.is_inside_tree():
		return
	
	var pos_raton = get_viewport().get_mouse_position()
	var desde = camara.project_ray_origin(pos_raton)
	var hasta = desde + camara.project_ray_normal(pos_raton) * 1000.0
	if camara == null:
		camara = get_viewport().get_camera_3d()
		if camara == null: return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camara.project_ray_origin(mouse_pos)
	var ray_direction = camara.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, global_position.y)
	var target_position = plane.intersects_ray(ray_origin, ray_direction)

	if target_position != null:
		target_position.y = global_position.y
		if global_position.distance_squared_to(target_position) > 0.001:
			look_at(target_position, Vector3.UP)
