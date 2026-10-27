class_name ArmaResource
extends Resource

@export_group("Identificación")
@export var nombre: String = "Espada Básica"
@export var icono: Texture2D

@export_group("Estadísticas de Combate")
@export var dano: float = 15.0
@export var consumo_estamina: float = 12.0
@export var cooldown_ataque: float = 0.5 # Velocidad de ataque
@export var tiempo_aturdimiento: float = 0.3 # Stun aplicado al enemigo
var emisor: Node3D = null

@export_group("Hitbox y Alcance")
@export var tamano_hitbox: Vector3 = Vector3(2.0, 1.5, 1.8) # Ancho, Alto, Profundidad
@export var alcance_distancia: float = 1.2 # Qué tan al frente se posiciona

func _on_body_entered(cuerpo: Node3D) -> void:
	if cuerpo == emisor:
		return
		
	# Depuración: Ver en consola qué cuerpo físico tocó el ataque
	print("Hitbox tocó a: ", cuerpo.name)

	if cuerpo is Enemigo or cuerpo.has_method("take_damage") or cuerpo.has_method("recibir_dano"):
		print("¡Impacto confirmado! Aplicando daño: ", dano)
		if cuerpo.has_method("take_damage"):
			cuerpo.take_damage(dano)
		elif cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano)
			
		if cuerpo.has_method("aplicar_aturdimiento"):
			cuerpo.aplicar_aturdimiento(tiempo_aturdimiento)
