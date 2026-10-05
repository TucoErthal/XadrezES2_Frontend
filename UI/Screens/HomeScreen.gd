extends Button
class_name HomeScreen

func _ready() -> void:
	pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	Router.load_level("res://Levels/Level.tscn")
	Router.navigate_to("GameUI")
