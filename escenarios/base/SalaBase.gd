extends Node3D

signal solicitar_cambio_sala(direccion_vector)
signal sala_despejada

@export var es_sala_combate: bool = true
var enemigos_vivos: int = 0

var material_bloqueado: StandardMaterial3D
var material_desbloqueado: StandardMaterial3D

@onready var puertas: Node3D = $Puertas
@onready var spawners: Node3D = $Spawners
@onready var puntos_entrada: Node3D = $PuntosEntrada

func _ready() -> void:
	_crear_materiales()
	_conectar_senales_puertas()
	
	if es_sala_combate:
		bloquear_puertas()
		call_deferred("iniciar_oleada")
	else:
		desbloquear_puertas()

func _conectar_senales_puertas() -> void:
	if puertas == null:
		return
		
	for puerta in puertas.get_children():
		if puerta.has_signal("jugador_cruzo_puerta"):
			if not puerta.jugador_cruzo_puerta.is_connected(_on_puerta_cruzada):
				puerta.jugador_cruzo_puerta.connect(_on_puerta_cruzada)

func _crear_materiales() -> void:
	material_bloqueado = StandardMaterial3D.new()
	material_bloqueado.albedo_color = Color.RED
	
	material_desbloqueado = StandardMaterial3D.new()
	material_desbloqueado.albedo_color = Color.GREEN

func _on_puerta_cruzada(direccion_vector: Vector2i) -> void:
	solicitar_cambio_sala.emit(direccion_vector)

## Devuelve la posición exacta del Marker3D de entrada correspondiente
func obtener_posicion_entrada(direccion_movimiento: Vector2i) -> Vector3:
	var nombre_punto := ""

	match direccion_movimiento:
		Vector2i(0, -1): nombre_punto = "Entrada_Abajo"   # Al avanzar hacia arriba, entras por el Sur
		Vector2i(0, 1):  nombre_punto = "Entrada_Arriba" # Al avanzar hacia abajo, entras por el Norte
		Vector2i(1, 0):  nombre_punto = "Entrada_Izquierda" # Al avanzar a la derecha, entras por el Oeste
		Vector2i(-1, 0): nombre_punto = "Entrada_Derecha"  # Al avanzar a la izquierda, entras por el Este

	if puntos_entrada != null:
		var punto = puntos_entrada.get_node_or_null(nombre_punto)
		if punto:
			return punto.global_position

	# Si falla la búsqueda, hace fallback al centro de la sala
	return global_position

func iniciar_oleada() -> void:
	if not es_sala_combate:
		desbloquear_puertas()
		return

	enemigos_vivos = 0
	if spawners == null or spawners.get_child_count() == 0:
		desbloquear_puertas()
		sala_despejada.emit()
		return

	for spawner in spawners.get_children():
		if spawner is SpawnerEnemigo:
			var nuevo_enemigo = spawner.spawnear_enemigo()
			if nuevo_enemigo != null:
				add_child(nuevo_enemigo)
				enemigos_vivos += 1
				nuevo_enemigo.tree_exited.connect(_on_enemigo_eliminado)
	
	if enemigos_vivos == 0:
		desbloquear_puertas()
		sala_despejada.emit()

func _on_enemigo_eliminado() -> void:
	enemigos_vivos -= 1
	if enemigos_vivos <= 0:
		desbloquear_puertas()
		sala_despejada.emit()

func bloquear_puertas() -> void:
	if puertas == null: return
	for puerta in puertas.get_children():
		if puerta.visible:
			if puerta is Area3D:
				puerta.set_deferred("monitoring", false)
				var malla = puerta.get_node_or_null("MallaPuerta") as MeshInstance3D
				if malla:
					malla.set_surface_override_material(0, material_bloqueado)
			
			var bloqueo = puerta.get_node_or_null("BloqueoFisico")
			if bloqueo and bloqueo is StaticBody3D:
				var colision = bloqueo.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if colision: colision.set_deferred("disabled", false)

func desbloquear_puertas() -> void:
	if puertas == null: return
	for puerta in puertas.get_children():
		if puerta.visible:
			if puerta is Area3D:
				puerta.set_deferred("monitoring", true)
				var malla = puerta.get_node_or_null("MallaPuerta") as MeshInstance3D
				if malla:
					malla.set_surface_override_material(0, material_desbloqueado)
			
			var bloqueo = puerta.get_node_or_null("BloqueoFisico")
			if bloqueo and bloqueo is StaticBody3D:
				var colision = bloqueo.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if colision: colision.set_deferred("disabled", true)
