extends Area3D

signal jugador_cruzo_puerta(direccion_vector)

var direccion_cuadricula: Vector2i = Vector2i.ZERO
var procesando_transicion: bool = false

func _ready() -> void:
	match name:
		"Puerta_Arriba":
			direccion_cuadricula = Vector2i(0, -1)
		"Puerta_Abajo":
			direccion_cuadricula = Vector2i(0, 1)
		"Puerta_Izquierda":
			direccion_cuadricula = Vector2i(-1, 0)
		"Puerta_Derecha":
			direccion_cuadricula = Vector2i(1, 0)
		_:
			pass

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if procesando_transicion:
		return
	if body is CharacterBody3D or body.is_in_group("Jugador") or body.name == "Jugador":
		procesando_transicion = true
		jugador_cruzo_puerta.emit(direccion_cuadricula)
		
		# Cooldown anti-doble disparo
		await get_tree().create_timer(1.0).timeout
		procesando_transicion = false
