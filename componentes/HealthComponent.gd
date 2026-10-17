class_name HealthComponent
extends Node

# Señales para notificar cambios de vida o la muerte
signal health_changed(current_health: float, max_health: float)
signal health_depleted

@export var max_health: float = 100.0:
	set(value):
		max_health = value
		# Ajustar vida actual si se cambia la vida máxima en runtime
		if current_health > max_health:
			current_health = max_health

var current_health: float

func _ready() -> void:
	current_health = max_health

## Aplica daño al objetivo. Devuelve true si el objetivo murió.
func take_damage(amount: float) -> bool:
	if amount <= 0 or current_health <= 0:
		return false
		
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		health_depleted.emit()
		return true
		
	return false

## Permite curar o regenerar vida
func heal(amount: float) -> void:
	if amount <= 0 or current_health <= 0:
		return
		
	current_health += amount
	current_health = clamp(current_health, 0.0, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0
