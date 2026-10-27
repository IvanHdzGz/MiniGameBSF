class_name SalaBase
extends Node3D

signal solicitar_cambio_sala(direccion_vector)
signal sala_despejada

enum TipoSala { NORMAL, INICIO, TESORO, TIENDA, SECRETA, SACRIFICIO, PACTOS, JEFE }

@export_group("Configuración de Sala")
@export var es_sala_combate: bool = true
@export var tipo_sala: TipoSala = TipoSala.NORMAL

@export_group("Configuración de Enemigos")
@export_range(1, 10, 1) var min_enemigos: int = 1
@export_range(1, 10, 1) var max_enemigos: int = 3

var enemigos_vivos: int = 0
var material_bloqueado: StandardMaterial3D
var material_desbloqueado: StandardMaterial3D

@onready var puertas: Node3D = $Puertas if has_node("Puertas") else null
@onready var spawners: Node3D = $Spawners if has_node("Spawners") else null
@onready var puntos_entrada: Node3D = $PuntosEntrada if has_node("PuntosEntrada") else null

func _ready() -> void:
	_crear_materiales()
	_conectar_senales_puertas()

func iniciar_sala() -> void:
	if es_sala_combate:
		bloquear_puertas()
		iniciar_oleada()
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

func obtener_posicion_entrada(direccion_movimiento: Vector2i) -> Vector3:
	var nombre_punto := ""

	match direccion_movimiento:
		Vector2i(0, -1): nombre_punto = "Entrada_Abajo"
		Vector2i(0, 1):  nombre_punto = "Entrada_Arriba"
		Vector2i(1, 0):  nombre_punto = "Entrada_Izquierda"
		Vector2i(-1, 0): nombre_punto = "Entrada_Derecha"

	if puntos_entrada != null:
		var punto = puntos_entrada.get_node_or_null(nombre_punto)
		if punto:
			return punto.global_position

	return global_position

func iniciar_oleada() -> void:
	enemigos_vivos = 0
	
	if spawners == null or spawners.get_child_count() == 0:
		desbloquear_puertas()
		sala_despejada.emit()
		return

	var lista_spawners: Array = []
	for spawner in spawners.get_children():
		if spawner is Spawner or spawner.has_method("spawnear_enemigo"):
			lista_spawners.append(spawner)

	if lista_spawners.size() == 0:
		desbloquear_puertas()
		sala_despejada.emit()
		return

	var es_jefe: bool = (tipo_sala == TipoSala.JEFE)
	var objetivo_enemigos: int = 1 if es_jefe else randi_range(min_enemigos, max_enemigos)

	for i in range(objetivo_enemigos):
		var spawner_elegido = lista_spawners.pick_random()
		var nuevo_enemigo = spawner_elegido.spawnear_enemigo(es_jefe)
		
		if nuevo_enemigo != null:
			var x_rand := randf_range(-15.5, 15.5)
			var z_rand := randf_range(-7.5, 7.5)
			nuevo_enemigo.position = Vector3(x_rand, 0.0, z_rand)
			
			add_child(nuevo_enemigo)
			enemigos_vivos += 1
			nuevo_enemigo.tree_exited.connect(_on_enemigo_eliminado)

	if enemigos_vivos == 0:
		desbloquear_puertas()
		sala_despejada.emit()

func _on_enemigo_eliminado() -> void:
	enemigos_vivos -= 1
	if enemigos_vivos <= 0:
		enemigos_vivos = 0
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
