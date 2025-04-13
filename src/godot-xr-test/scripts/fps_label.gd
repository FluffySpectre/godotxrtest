class_name FPSLabel extends Label3D

# Update rate for the FPS display (in seconds)
var _update_interval = 0.5
var _time_passed = 0.0

func _ready() -> void:
  text = "FPS: 0"
  billboard = BaseMaterial3D.BILLBOARD_ENABLED
  double_sided = true

func _process(delta) -> void:
  _time_passed += delta
  
  # Update text only after the interval has passed
  if _time_passed >= _update_interval:
    var current_fps = Engine.get_frames_per_second()
    text = "FPS: " + str(current_fps)
    _time_passed = 0.0
