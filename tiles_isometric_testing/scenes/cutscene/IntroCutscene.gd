extends Node2D

@onready var cutscene_animator: AnimationPlayer = $CutsceneAnimator

func _ready() -> void:
	# Ensure the transition rect is initially transparent
	if has_node("TransitionRect"):
		$TransitionRect.modulate = Color(1, 1, 1, 0)
	
	if cutscene_animator.has_animation("play_cutscene"):
		cutscene_animator.play("play_cutscene")
		cutscene_animator.animation_finished.connect(_on_animation_finished)
	else:
		printerr("Cutscene animation 'play_cutscene' not found!")
		_finish_cutscene()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		# Cari batas waktu scene berikutnya (kelipatan 15 detik)
		var current_time = cutscene_animator.current_animation_position
		var next_time = floor((current_time / 15.0) + 1.0) * 15.0
		
		# Jika scene berikutnya melebihi atau sama dengan durasi total cutscene, kita akhiri cutscene
		if next_time >= cutscene_animator.current_animation_length:
			_finish_cutscene()
		else:
			# Lompat ke scene berikutnya
			cutscene_animator.seek(next_time, true)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "play_cutscene":
		_finish_cutscene()

func _finish_cutscene() -> void:
	# Di sini kamu bisa memanggil SceneManager atau mengubah scene ke Main Menu / Game
	# Untuk saat ini kita cukup cetak pesan dan mungkin transisi ke scene lain
	print("Cutscene finished or skipped. Transitioning to next scene...")
	
	# TODO: Ganti path ini dengan path scene utama kamu
	# get_tree().change_scene_to_file("res://ui/menu/MainMenu.tscn")
	pass
