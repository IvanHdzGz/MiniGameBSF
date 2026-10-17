# Script adjunto a una Area3D Puerta_Norte
extends Area3D

signal jugador_cruzo_puerta(direccion)

@export var direccion_puerta: String = "Norte"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador") or body.name == "Jugador":
		if body.has_method("recibir_daño"): # o la función de salud que uses
			body.recibir_daño(10)
			
		
		# Desactivar colisión inmediatamente para evitar un segundo impacto
		$CollisionShape3D.set_deferred("disabled", true)
		queue_free() # Destruir el proyectil / ataque
