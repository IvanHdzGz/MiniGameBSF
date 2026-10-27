class_name Spawner
extends Node3D

@export_group("Pool de Enemigos")
@export var enemigos_normales: Array[PackedScene] = []
@export var enemigos_jefe: Array[PackedScene] = []

@export_group("Probabilidades")
@export_range(0.0, 1.0) var probabilidad_elite: float = 0.15 # 15% de ser Élite en sala normal

func spawnear_enemigo(es_sala_jefe: bool = false) -> CharacterBody3D:
	var escena_elegida: PackedScene = null

	if es_sala_jefe:
		if enemigos_jefe.size() > 0:
			escena_elegida = enemigos_jefe.pick_random()
	else:
		if enemigos_normales.size() > 0:
			escena_elegida = enemigos_normales.pick_random()

	if escena_elegida == null:
		return null

	var instancia = escena_elegida.instantiate()
	if instancia is Enemigo:
		if not es_sala_jefe and randf() <= probabilidad_elite:
			instancia.rango = Enemigo.RangoEnemigo.ELITE
		elif es_sala_jefe:
			instancia.rango = Enemigo.RangoEnemigo.JEFE

	return instancia as CharacterBody3D
