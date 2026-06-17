extends Control
class_name RarityRevealUI

# Handles the visual feedback (glow/animations) when an item is revealed/picked up.

@onready var glow_rect: ColorRect = $GlowRect # Needs to be setup in the scene
@onready var item_icon: TextureRect = $ItemIcon
@onready var label_name: Label = $LabelName

func reveal_item(item_data: Dictionary) -> void:
	if not is_inside_tree():
		return
		
	var rarity = item_data.get("rarity", ItemRegistry.Rarity.COMMON)
	var glow_color: Color
	
	match rarity:
		ItemRegistry.Rarity.COMMON:
			glow_color = Color(1.0, 1.0, 1.0, 0.8) # White
		ItemRegistry.Rarity.RARE:
			glow_color = Color(0.2, 0.5, 1.0, 0.8) # Blue
		ItemRegistry.Rarity.LEGENDARY:
			glow_color = Color(1.0, 0.8, 0.2, 0.8) # Gold
		ItemRegistry.Rarity.CURSED:
			glow_color = Color(0.5, 0.0, 0.8, 0.8) # Purple
	
	label_name.text = item_data.get("name", "Unknown Item")
	
	# Play Tween Animation
	var tween = create_tween()
	
	# Flash the glow
	glow_rect.modulate = glow_color
	glow_rect.modulate.a = 0.0
	tween.tween_property(glow_rect, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow_rect, "modulate:a", 0.0, 0.5).set_delay(1.0)
	
	# Pop the icon
	item_icon.scale = Vector2.ZERO
	tween.parallel().tween_property(item_icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
