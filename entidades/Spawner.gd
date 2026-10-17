extends Node3D
class_name SpawnerEnemigo

@export var escena_enemigo: PackedScene = preload("res://entidades/enemigos/Enemigo_Dummy.tscn")

func spawnear_enemigo() -> Node3D:
	if escena_enemigo == null:
		return null
		
	var enemigo = escena_enemigo.instantiate()
	enemigo.global_position = global_position
	return enemigo
