extends Area3D

@export var velocidad: float = 15.0
@export var dano: float = 20.0
@export var tiempo_vida: float = 3.0

# DECLARAR ESTA VARIABLE ES LO QUE SOLUCIONA EL ERROR:
var direccion: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Conectamos la colisión
	body_entered.connect(_on_body_entered)
	
	# Destruir automáticamente después de unos segundos si no choca con nada
	var timer = get_tree().create_timer(tiempo_vida)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Mover el proyectil en la dirección asignada
	if direccion != Vector3.ZERO:
		global_position += direccion * velocidad * delta

func _on_body_entered(body: Node) -> void:
	# Evitar hacerse daño a uno mismo o chocar con otras áreas que no sean cuerpos
	if body.has_method("take_damage"):
		body.take_damage(dano)
		queue_free()
	elif not body is CharacterBody3D and not body is RigidBody3D:
		# Choque contra pared/obstáculo
		queue_free()
