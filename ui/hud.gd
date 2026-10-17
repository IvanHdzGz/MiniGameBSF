extends CanvasLayer

@onready var barra_salud: ProgressBar = $MarginContainer/BarraSalud
@onready var barra_estamina: ProgressBar = $MarginContainer/BarraEstamina

func actualizar_salud(actual: float, maxima: float) -> void:
	if barra_salud:
		barra_salud.max_value = maxima
		barra_salud.value = actual

func actualizar_estamina(actual: float, maxima: float) -> void:
	if barra_estamina:
		barra_estamina.max_value = maxima
		barra_estamina.value = actual
