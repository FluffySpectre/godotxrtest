class_name FPSLabel extends Label3D

const UPDATE_INTERVAL = 0.5 # Update rate for the FPS display (in seconds)
var _time_passed = 0.0

func _ready() -> void:
  text = "FPS: 0"
  billboard = BaseMaterial3D.BILLBOARD_ENABLED
  double_sided = true

func _process(delta: float) -> void:
  _time_passed += delta
  
  if _time_passed >= UPDATE_INTERVAL:
    var current_fps = Engine.get_frames_per_second()
    text = "FPS: " + str(current_fps)
    _time_passed = 0.0
