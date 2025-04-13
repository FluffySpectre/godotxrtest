class_name AppManager extends Node3D

@export var xr_manager: XRManager

func _ready() -> void:
  pass
  #xr_manager.instance.focus_gained.connect(_on_focus_gained)

func _on_focus_gained() -> void:
  xr_manager.instance.switch_to_ar()
