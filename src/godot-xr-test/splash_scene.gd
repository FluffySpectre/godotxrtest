extends BaseScene

@export var splash_duration: float = 2.0
@export_file("*.tscn") var main_scene: String

func scene_visible(user_data = null) -> void:
  await get_tree().create_timer(splash_duration).timeout
  
  request_load_scene_f(main_scene, user_data)
