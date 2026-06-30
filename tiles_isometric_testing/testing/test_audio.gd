extends SceneTree

func _init() -> void:
	print("\n==============================================")
	print("📢 RUNNING AUDIO MANAGER SMOKE TEST (SYNC)...")
	print("==============================================\n")
	
	var script = load("res://autoloads/AudioManager.gd")
	if script == null:
		print("❌ ERROR: Cannot load res://autoloads/AudioManager.gd!")
		quit(1)
		return
		
	var am = script.new()
	# Call resources loading manually to check paths
	am._load_resources()
	
	var sfx_keys = am.sound_effects.keys()
	var bgm_keys = am.bgm_tracks.keys()
	
	print("SFX Loaded Count: %d / %d" % [sfx_keys.size(), am.SFX_PATHS.size()])
	print("BGM Loaded Count: %d / %d" % [bgm_keys.size(), am.BGM_PATHS.size()])
	
	var missing_sfx = []
	for k in am.SFX_PATHS.keys():
		if not am.sound_effects.has(k):
			missing_sfx.append(k)
			
	var missing_bgm = []
	for k in am.BGM_PATHS.keys():
		if not am.bgm_tracks.has(k):
			missing_bgm.append(k)
			
	if missing_sfx.size() > 0:
		print("❌ Missing SFX Resources: ", missing_sfx)
	if missing_bgm.size() > 0:
		print("❌ Missing BGM Resources: ", missing_bgm)
		
	if missing_sfx.size() > 0 or missing_bgm.size() > 0:
		print("\n❌ TEST FAILED: Some resources failed to load.")
		quit(1)
	else:
		print("\n✅ TEST PASSED: All audio resources successfully preloaded!")
		quit(0)
