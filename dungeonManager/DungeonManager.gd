extends Node3D

@export_group("Configuración de Mazmorra")
@export var sala_inicio_scene: PackedScene
@export var salas_combate_scenes: Array[PackedScene] = []
@export var jugador_scene: PackedScene
@export_range(1, 100, 1) var min_salas_normales: int = 5
@export_range(1, 100, 1) var max_salas_normales: int = 15

var total_salas_normales: int

@export_group("Salas Especiales")
@export var sala_jefe_scene: PackedScene
@export var sala_tesoro_scene: PackedScene
@export var sala_tienda_scene: PackedScene
@export var sala_secreta_scene: PackedScene
@export var sala_sacrificio_scene: PackedScene
@export var sala_pactos_scene: PackedScene

@export_subgroup("Probabilidades Especiales")
@export_range(0.0, 1.0) var probabilidad_sacrificio: float = 0.4
@export_range(0.0, 1.0) var probabilidad_pactos: float = 0.5

@export_group("Interfaz UI")
@export var minimapa_node: Control

const TAMANO_MATRIZ: int = 13
const COORD_INICIAL := Vector2i(6, 6)

var matriz_mazmorra: Array = []
var coordenada_actual: Vector2i = COORD_INICIAL

var sala_instanciada_actual: Node3D = null
var jugador_instancia: CharacterBody3D = null
var puedo_cambiar_sala: bool = true

const DIRECCIONES = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

enum TipoSala { NORMAL, INICIO, TESORO, TIENDA, SECRETA, SACRIFICIO, PACTOS, JEFE }

func _ready() -> void:
	inicializar_matriz_vacia()
	total_salas_normales = randi_range(min_salas_normales, max_salas_normales)
	generar_layout()
	instanciar_jugador()
	
	if minimapa_node and minimapa_node.has_method("inicializar"):
		minimapa_node.inicializar(self)
		
	cargar_sala_en(COORD_INICIAL, Vector2i.ZERO)

func inicializar_matriz_vacia() -> void:
	matriz_mazmorra.clear()
	for x in range(TAMANO_MATRIZ):
		var columna := []
		for y in range(TAMANO_MATRIZ):
			columna.append(null)
		matriz_mazmorra.append(columna)

func es_coordenada_valida(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < TAMANO_MATRIZ and coord.y >= 0 and coord.y < TAMANO_MATRIZ

func obtener_datos_sala(coord: Vector2i):
	if not es_coordenada_valida(coord):
		return null
	return matriz_mazmorra[coord.x][coord.y]

func fijar_datos_sala(coord: Vector2i, datos) -> void:
	if es_coordenada_valida(coord):
		matriz_mazmorra[coord.x][coord.y] = datos

func generar_layout() -> void:
	inicializar_matriz_vacia()
	
	# Sala Inicial:
	fijar_datos_sala(COORD_INICIAL, {
		"escena": sala_inicio_scene,
		"tipo": TipoSala.INICIO,
		"visitada": true,
		"completada": true,
		"descubierta": true
	})
	
	# FASE 1: Generar esqueleto de salas normales de combate
	var salas_creadas := 1
	var historial_posiciones: Array[Vector2i] = [COORD_INICIAL]
	
	while salas_creadas < total_salas_normales:
		var pos_base = historial_posiciones.pick_random()
		var dir = DIRECCIONES.pick_random()
		var nueva_pos = pos_base + dir
		
		if es_coordenada_valida(nueva_pos) and obtener_datos_sala(nueva_pos) == null:
			var escena_elegida: PackedScene = sala_inicio_scene
			if salas_combate_scenes.size() > 0:
				escena_elegida = salas_combate_scenes.pick_random()

			# Salas Normales:
			fijar_datos_sala(nueva_pos, {
				"escena": escena_elegida,
				"tipo": TipoSala.NORMAL,
				"visitada": false,
				"completada": false,
				"descubierta": false
			})
			historial_posiciones.append(nueva_pos)
			salas_creadas += 1

	# FASE 2: Asignar Salas Especiales
	colocar_salas_especiales()

func colocar_salas_especiales() -> void:
	# Casillas vacías que colindan con EXACTAMENTE 1 sala (Callejones / Entrada Única)
	var lista_hojas := obtener_posiciones_con_vecinos_exactos(1)
	lista_hojas.shuffle()

	# Función auxiliar local para extraer una casilla que solo colinde con salas normales/inicio
	var obtener_hoja_valida = func() -> Vector2i:
		for i in range(lista_hojas.size() - 1, -1, -1):
			var cand = lista_hojas[i]
			if _es_hoja_conectada_a_sala_normal(cand):
				lista_hojas.remove_at(i)
				return cand
		return Vector2i(-1, -1)

	# 1. SALA DE JEFE (Garantizada y aislada)
	if sala_jefe_scene and lista_hojas.size() > 0:
		var pos_jefe = obtener_hoja_valida.call()
		if pos_jefe != Vector2i(-1, -1):
			fijar_datos_sala(pos_jefe, {
				"escena": sala_jefe_scene,
				"tipo": TipoSala.JEFE,
				"visitada": false,
				"completada": false,
				"descubierta": false
			})

	# 2. SALA TESORO (Garantizada y aislada)
	if sala_tesoro_scene and lista_hojas.size() > 0:
		var pos_tesoro = obtener_hoja_valida.call()
		if pos_tesoro != Vector2i(-1, -1):
			fijar_datos_sala(pos_tesoro, {
				"escena": sala_tesoro_scene,
				"tipo": TipoSala.TESORO,
				"visitada": false,
				"completada": true,
				"descubierta": false
			})

	# 3. SALA TIENDA (Garantizada y aislada)
	if sala_tienda_scene and lista_hojas.size() > 0:
		var pos_tienda = obtener_hoja_valida.call()
		if pos_tienda != Vector2i(-1, -1):
			fijar_datos_sala(pos_tienda, {
				"escena": sala_tienda_scene,
				"tipo": TipoSala.TIENDA,
				"visitada": false,
				"completada": true,
				"descubierta": false
			})

	# 4. SALA SACRIFICIO (Probabilística y aislada)
	if sala_sacrificio_scene and randf() <= probabilidad_sacrificio and lista_hojas.size() > 0:
		var pos_sacrificio = obtener_hoja_valida.call()
		if pos_sacrificio != Vector2i(-1, -1):
			fijar_datos_sala(pos_sacrificio, {
				"escena": sala_sacrificio_scene,
				"tipo": TipoSala.SACRIFICIO,
				"visitada": false,
				"completada": true,
				"descubierta": false
			})

	# 5. SALA PACTOS (Probabilística y aislada)
	if sala_pactos_scene and randf() <= probabilidad_pactos and lista_hojas.size() > 0:
		var pos_pactos = obtener_hoja_valida.call()
		if pos_pactos != Vector2i(-1, -1):
			fijar_datos_sala(pos_pactos, {
				"escena": sala_pactos_scene,
				"tipo": TipoSala.PACTOS,
				"visitada": false,
				"completada": true,
				"descubierta": false
			})

	# 6. SALA SECRETA (Se coloca al final, con 2 a 4 accesos)
	if sala_secreta_scene:
		var candidatas_secretas = obtener_posiciones_con_vecinos_exactos(4)
		candidatas_secretas.append_array(obtener_posiciones_con_vecinos_exactos(3))
		if candidatas_secretas.size() == 0:
			candidatas_secretas = obtener_posiciones_con_vecinos_exactos(2)
			
		if candidatas_secretas.size() > 0:
			candidatas_secretas.shuffle()
			var pos_secreta = candidatas_secretas.pop_back()
			fijar_datos_sala(pos_secreta, {
				"escena": sala_secreta_scene,
				"tipo": TipoSala.SECRETA,
				"visitada": false,
				"completada": true,
				"descubierta": false
			})

func obtener_posiciones_con_vecinos_exactos(num_vecinos_requeridos: int) -> Array[Vector2i]:
	var candidatas: Array[Vector2i] = []
	for x in range(TAMANO_MATRIZ):
		for y in range(TAMANO_MATRIZ):
			var pos := Vector2i(x, y)
			if obtener_datos_sala(pos) == null:
				var vecinos_encontrados := 0
				for dir in DIRECCIONES:
					var vecino_pos = pos + dir
					if es_coordenada_valida(vecino_pos) and obtener_datos_sala(vecino_pos) != null:
						vecinos_encontrados += 1
				if vecinos_encontrados == num_vecinos_requeridos:
					candidatas.append(pos)
	return candidatas

func instanciar_jugador() -> void:
	var jugador_existente = get_tree().get_first_node_in_group("Jugador")
	if jugador_existente:
		jugador_instancia = jugador_existente as CharacterBody3D
		return

	if jugador_scene and jugador_instancia == null:
		jugador_instancia = jugador_scene.instantiate() as CharacterBody3D
		if not jugador_instancia.is_in_group("Jugador"):
			jugador_instancia.add_to_group("Jugador")
		add_child(jugador_instancia)

func cargar_sala_en(coordenada: Vector2i, direccion_entrada: Vector2i = Vector2i.ZERO) -> void:
	puedo_cambiar_sala = false
	
	# 1. Limpiar sala previa y señales
	if sala_instanciada_actual and is_instance_valid(sala_instanciada_actual):
		if sala_instanciada_actual.has_signal("solicitar_cambio_sala"):
			if sala_instanciada_actual.solicitar_cambio_sala.is_connected(_on_solicitud_cambio_sala):
				sala_instanciada_actual.solicitar_cambio_sala.disconnect(_on_solicitud_cambio_sala)
		
		sala_instanciada_actual.queue_free()
		sala_instanciada_actual = null
	
	# 2. Limpiar proyectiles
	var proyectiles = get_tree().get_nodes_in_group("Proyectiles")
	for p in proyectiles:
		if is_instance_valid(p):
			p.queue_free()

	var datos_sala = obtener_datos_sala(coordenada)
	if datos_sala == null:
		puedo_cambiar_sala = true
		return

	var empaquetada: PackedScene = datos_sala.get("escena", null)
	if empaquetada == null:
		empaquetada = sala_inicio_scene

	# 3. Instanciar e inyectar el Tipo de Sala ANTES de add_child
	sala_instanciada_actual = empaquetada.instantiate()
	
	if "tipo_sala" in sala_instanciada_actual:
		sala_instanciada_actual.tipo_sala = datos_sala.get("tipo", TipoSala.NORMAL)

	datos_sala["visitada"] = true
	if datos_sala.get("completada", false):
		sala_instanciada_actual.es_sala_combate = false

	# 4. Añadir la sala al árbol
	add_child(sala_instanciada_actual)
	coordenada_actual = coordenada

	# 5. Conectar señales
	if sala_instanciada_actual.has_signal("sala_despejada"):
		if not sala_instanciada_actual.sala_despejada.is_connected(_on_sala_despejada):
			sala_instanciada_actual.sala_despejada.connect(_on_sala_despejada.bind(coordenada))

	if sala_instanciada_actual.has_signal("solicitar_cambio_sala"):
		sala_instanciada_actual.solicitar_cambio_sala.connect(_on_solicitud_cambio_sala)

	# 6. Configurar la visibilidad física de las puertas según la matriz
	configurar_puertas_de_sala(coordenada)
	
	# 7. Mover al jugador al Marker3D correspondiente
	reposicionar_jugador(direccion_entrada)

	# 8. Iniciar la lógica de la sala (bloqueo / oleada)
	if sala_instanciada_actual.has_method("iniciar_sala"):
		sala_instanciada_actual.iniciar_sala()

	# 9. Actualizar minimapa
	if minimapa_node != null:
		if minimapa_node.has_method("actualizar_minimapa"):
			minimapa_node.actualizar_minimapa()
		elif minimapa_node.has_method("queue_redraw"):
			minimapa_node.queue_redraw()

	get_tree().create_timer(0.3).timeout.connect(func(): puedo_cambiar_sala = true)

func _on_sala_despejada(coordenada: Vector2i) -> void:
	var datos = obtener_datos_sala(coordenada)
	if datos != null:
		datos["completada"] = true

func reposicionar_jugador(direccion_entrada: Vector2i) -> void:
	if direccion_entrada == Vector2i.ZERO:
		return

	var jugador = jugador_instancia
	if not jugador:
		jugador = get_tree().get_first_node_in_group("Jugador") as CharacterBody3D

	if not jugador or not sala_instanciada_actual:
		return

	if sala_instanciada_actual.has_method("obtener_posicion_entrada"):
		var pos_spawn = sala_instanciada_actual.obtener_posicion_entrada(direccion_entrada)
		jugador.velocity = Vector3.ZERO
		jugador.global_position = pos_spawn

func configurar_puertas_de_sala(coordenada: Vector2i) -> void:
	var nodo_puertas = sala_instanciada_actual.get_node_or_null("Puertas")
	if nodo_puertas == null: return

	var mapa_puertas = {
		Vector2i(0, -1): "Puerta_Arriba",
		Vector2i(0, 1):  "Puerta_Abajo",
		Vector2i(-1, 0): "Puerta_Izquierda",
		Vector2i(1, 0):  "Puerta_Derecha"
	}

	for dir in mapa_puertas.keys():
		var nombre_puerta = mapa_puertas[dir]
		var puerta_node = nodo_puertas.get_node_or_null(nombre_puerta)
		var vecino_pos = coordenada + dir
		
		if puerta_node:
			var datos_vecino = obtener_datos_sala(vecino_pos)
			var existe_vecino = (datos_vecino != null)
			
			if not existe_vecino:
				puerta_node.visible = false
				
				if puerta_node is Area3D:
					puerta_node.set_deferred("monitoring", false)
					puerta_node.set_deferred("monitorable", false)
					var col_area = puerta_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
					if col_area: col_area.set_deferred("disabled", true)
				
				var bloqueo = puerta_node.get_node_or_null("BloqueoFisico")
				if bloqueo:
					var col_bloqueo = bloqueo.get_node_or_null("CollisionShape3D") as CollisionShape3D
					if col_bloqueo: col_bloqueo.set_deferred("disabled", true)
			else:
				puerta_node.visible = true

func _on_solicitud_cambio_sala(direccion_vector: Vector2i) -> void:
	if not puedo_cambiar_sala:
		return

	var nueva_coordenada = coordenada_actual + direccion_vector
	if es_coordenada_valida(nueva_coordenada) and obtener_datos_sala(nueva_coordenada) != null:
		call_deferred("cargar_sala_en", nueva_coordenada, direccion_vector)

## Verifica que una posición con 1 solo vecino esté conectada a una sala de COMBATE/NORMAL o INICIO
func _es_hoja_conectada_a_sala_normal(pos: Vector2i) -> bool:
	for dir in DIRECCIONES:
		var vecino_pos = pos + dir
		if es_coordenada_valida(vecino_pos):
			var datos_vecino = obtener_datos_sala(vecino_pos)
			if datos_vecino != null:
				var tipo_vecino = datos_vecino.get("tipo", -1)
				# Solo es válida si su única sala colindante es NORMAL o INICIO
				return tipo_vecino == TipoSala.NORMAL or tipo_vecino == TipoSala.INICIO
	return false
