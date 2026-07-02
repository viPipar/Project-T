extends CanvasLayer

const GAME_SCENE_PATH = "res://main/Main.tscn"

var _loaded: bool = false

func _ready() -> void:
	layer = 300
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	add_child(bg)

	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)

func _process(_delta: float) -> void:
	if _loaded:
		return

	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_loaded = true
			_swap()

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[LoadingScreen] Failed to load Main.tscn")
			set_process(false)

func _swap() -> void:
	var packed = ResourceLoader.load_threaded_get(GAME_SCENE_PATH)
	if packed == null:
		return

	var game = packed.instantiate()
	if game == null:
		return

	var root = get_tree().root
	root.add_child(game)
	get_tree().current_scene = game
	queue_free()
