extends Node3D

@onready var help_overlay: ColorRect = %HelpOverlay

func _on_help_button_pressed() -> void:
	help_overlay.show()

func _on_close_button_pressed() -> void:
	help_overlay.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		help_overlay.hide()
