extends Control

@onready var loading_label: Label = $CenterContainer/LoadingLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	loading_label.text = "Loading..."
