extends BaseScene

@onready var _height_measurement: HeightMeasurement = $HeightMeasurement

var _next_scene_path: String

func _ready() -> void:
  super()
  
  _height_measurement.completed.connect(_on_height_measurement_completed)

func _exit_tree() -> void:
  _height_measurement.completed.disconnect(_on_height_measurement_completed)

func _on_height_measurement_completed() -> void:
  request_load_scene_f(_next_scene_path)

func scene_visible(user_data = null) -> void:
  _next_scene_path = user_data
