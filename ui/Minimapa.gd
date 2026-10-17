extends Control

# --- CONFIGURACIÓN VISUAL ---
@export var tamano_celda: Vector2 = Vector2(20, 16) # Tamaño en px de cada rectángulo
@export var separacion: Vector2 = Vector2(3, 3)     # Espaciado entre rectángulos

# --- COLORES ---
@export var color_sala_actual := Color(0.2, 0.9, 0.3, 1.0)       # Verde brillante
@export var color_visitada := Color(0.7, 0.7, 0.7, 0.9)          # Gris claro
@export var color_adyacente := Color(0.4, 0.4, 0.4, 0.4)         # Gris tenue/transparente
@export var color_borde := Color(0.1, 0.1, 0.1, 0.8)            # Borde negro suave
# --- COLORES DE SALAS ESPECIALES (RGB 0-255) ---
@export var color_sacrificio := Color8(255, 0, 0)       # Rojo puro
@export var color_secreta := Color8(80, 0, 120)        # Morado oscuro
@export var color_tesoro := Color8(255, 255, 0)        # Amarillo
@export var color_tienda := Color8(255, 150, 0)        # Naranja
@export var color_pacto1 := Color8(255, 255, 255)      # Blanco
@export var color_pacto2 := Color8(0, 0, 0)            # Negro

var manager_mazmorra: Node3D = null

func _ready() -> void:
	# Aseguramos que el nodo sea visible
	visible = true
	set_process(false)

## Llamar a esta función desde DungeonManager al iniciar o al cargar la escena
func inicializar(dungeon_manager: Node3D) -> void:
	manager_mazmorra = dungeon_manager
	queue_redraw()

## Forzar la actualización del dibujo cuando el jugador cambia de sala
func actualizar_minimapa() -> void:
	queue_redraw()

func _draw() -> void:
	if manager_mazmorra == null:
		return

	var coord_actual = manager_mazmorra.coordenada_actual
	var tamano_matriz = manager_mazmorra.TAMANO_MATRIZ

	for x in range(tamano_matriz):
		for y in range(tamano_matriz):
			var pos_evaluada := Vector2i(x, y)
			var datos_sala = manager_mazmorra.obtener_datos_sala(pos_evaluada)

			if datos_sala == null:
				continue

			var es_actual = (pos_evaluada == coord_actual)
			var es_visitada = bool(datos_sala.get("visitada", false))
			
			# Descubrir automáticamente las salas adyacentes a la sala actual
			if _es_adyacente_a_posicion(pos_evaluada, coord_actual):
				datos_sala["descubierta"] = true

			var es_descubierta = bool(datos_sala.get("descubierta", false))

			var color_dibujo := Color.TRANSPARENT
			var dibujar_sala := false

			# 1. SALA ACTUAL
			if es_actual:
				color_dibujo = color_sala_actual
				dibujar_sala = true

			# 2. SALAS VISITADAS O DESCUBIERTAS (PERMANENTES)
			elif es_visitada or es_descubierta:
				var tipo = datos_sala.get("tipo", 0) # 0 = NORMAL, 1 = INICIO
				
				# Determinar color por tipo de sala especial
				match tipo:
					2: color_dibujo = color_tesoro     # TipoSala.TESORO
					3: color_dibujo = color_tienda     # TipoSala.TIENDA
					4: color_dibujo = color_secreta    # TipoSala.SECRETA
					5: color_dibujo = color_sacrificio # TipoSala.SACRIFICIO
					6: color_dibujo = color_pacto1     # TipoSala.PACTOS (Pacto 1)
					_: 
						if es_visitada:
							color_dibujo = color_visitada
						else:
							color_dibujo = color_adyacente # Gris transparente para adyacentes no visitadas
				
				dibujar_sala = true

			if dibujar_sala:
				var pos_local := Vector2(
					x * (tamano_celda.x + separacion.x),
					y * (tamano_celda.y + separacion.y)
				)
				var rect := Rect2(pos_local, tamano_celda)

				draw_rect(rect, color_dibujo, true)
				draw_rect(rect, color_borde, false, 1.5)

## Comprueba si la coordenada evaluada está justo al lado (N, S, E, O) de la sala actual
func _es_adyacente_a_posicion(pos_evaluada: Vector2i, centro: Vector2i) -> bool:
	var diff = (pos_evaluada - centro).abs()
	# Es adyacente en ortogonal si la distancia Manhattan es 1 (Arriba, Abajo, Izq, Der)
	return (diff.x + diff.y) == 1
