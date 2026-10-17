extends CharacterBody3D

# --- ESTADÍSTICAS ---
@export var salud_maxima: float = 100.0
var salud_actual: float = 100.0

@export var estamina_maxima: float = 100.0
var estamina_actual: float = 100.0
const REGEN_ESTAMINA: float = 20.0
const COSTO_DASH: float = 25.0
const COSTO_SPRINT: float = 15.0

# --- MOVIMIENTO ---
const WALK_SPEED: float = 6.0
const SPRINT_SPEED: float = 10.0
const DASH_BASE_SPEED: float = 18.0
const DASH_SPRINT_SPEED: float = 24.0

const DASH_DURATION: float = 0.22
const ATAQUE_COOLDOWN: float = 0.25

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

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	apuntar_al_raton()

	# Manejo de Estamina y Esprint
	var wants_to_sprint := Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	var is_sprinting := false

	if wants_to_sprint and estamina_actual > 0:
		is_sprinting = true
		estamina_actual = max(0.0, estamina_actual - COSTO_SPRINT * delta)
	elif not is_dashing and estamina_actual < estamina_maxima:
		estamina_actual = min(estamina_maxima, estamina_actual + REGEN_ESTAMINA * delta)

	# Manejo de Dash
	if Input.is_action_just_pressed("ui_accept") and not is_dashing and direction != Vector3.ZERO:
		if estamina_actual >= COSTO_DASH:
			ejecutar_dash(is_sprinting)

	# Ataque
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and puede_atacar and not is_dashing:
		atacar()

	# Cálculo de velocidad
	var target_speed: float
	if is_dashing:
		target_speed = current_dash_speed
	elif is_sprinting:
		target_speed = SPRINT_SPEED
	else:
		target_speed = WALK_SPEED

	if direction != Vector3.ZERO:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, target_speed)
		velocity.z = move_toward(velocity.z, 0, target_speed)

	move_and_slide()
	actualizar_hud()

func ejecutar_dash(is_sprinting: bool) -> void:
	estamina_actual -= COSTO_DASH
	is_dashing = true
	is_invulnerable = true
	current_dash_speed = DASH_SPRINT_SPEED if is_sprinting else DASH_BASE_SPEED
	
	get_tree().create_timer(DASH_DURATION).timeout.connect(func():
		is_dashing = false
		is_invulnerable = false
	)

func atacar() -> void:
	if escena_ataque == null:
		return
		
	puede_atacar = false
	get_tree().create_timer(ATAQUE_COOLDOWN).timeout.connect(func(): puede_atacar = true)

	var proyectil = escena_ataque.instantiate()
	proyectil.global_position = global_position + (-transform.basis.z * 1.2)
	proyectil.direccion = -transform.basis.z
	get_parent().add_child(proyectil)

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
