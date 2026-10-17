extends CharacterBody3D

@export var salud: int = 30
@export var velocidad: float = 3.5
@export var dano_ataque: int = 10
@export var cooldown_ataque: float = 1.0

var jugador: Node3D = null
var ultimo_golpe_tiempo: int = 0

@onready var area_ataque: Area3D = $AreaAtaque
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	# Buscar al jugador en el grupo
	var nodos_jugador = get_tree().get_nodes_in_group("Jugador")
	if nodos_jugador.size() > 0:
		jugador = nodos_jugador[0]
	if health_component:
		health_component.max_health = salud
		health_component.current_health = salud

	# Conectar el daño solo desde el enemigo
	if area_ataque and not area_ataque.body_entered.is_connected(_on_area_ataque_body_entered):
		area_ataque.body_entered.connect(_on_area_ataque_body_entered)
		
	if health_component and not health_component.health_depleted.is_connected(_on_health_depleted):
		health_component.health_depleted.connect(_on_health_depleted)

func _physics_process(_delta: float) -> void:
	# Movimiento hacia el jugador
	if jugador != null:
		var direccion = (jugador.global_position - global_position).normalized()
		direccion.y = 0 
		velocity = direccion * velocidad
		move_and_slide()

	# Si el jugador se queda pegado al enemigo, aplicar daño cada cierto tiempo
	if area_ataque.has_overlapping_bodies():
		for body in area_ataque.get_overlapping_bodies():
			intentar_aplicar_dano(body)

func _on_area_ataque_body_entered(body: Node3D) -> void:
	intentar_aplicar_dano(body)

func intentar_aplicar_dano(body: Node3D) -> void:
	if body.is_in_group("Jugador") or body.name == "Jugador":
		var tiempo_actual = Time.get_ticks_msec()
		
		if tiempo_actual - ultimo_golpe_tiempo >= int(cooldown_ataque * 1000):
			if body.has_method("recibir_dano"):
				ultimo_golpe_tiempo = tiempo_actual
				body.recibir_dano(dano_ataque)

func take_damage(amount: float) -> void:
	if health_component:
		health_component.take_damage(amount)
	
func _on_health_depleted() -> void:
	queue_free()
