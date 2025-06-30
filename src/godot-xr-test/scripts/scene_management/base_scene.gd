class_name BaseScene extends Node3D

signal request_exit_to_main
signal request_load_scene(scene_path, user_data)
signal request_reset_scene(user_data)
signal request_quit

func _ready() -> void:
  pass

func scene_loaded(user_data = null) -> void:
  $XROrigin3D/XRCamera3D.current = true
  $XROrigin3D.current = true

func scene_visible(user_data = null) -> void:
  pass

func scene_pre_exiting(user_data = null) -> void:
  pass

func scene_exiting(user_data = null) -> void:
  pass

func request_exit_to_main_f() -> void:
  request_exit_to_main.emit()

func request_load_scene_f(scene_path, user_data = null) -> void:
  request_load_scene.emit(scene_path, user_data)

func request_reset_scene_f(user_data = null) -> void:
  request_reset_scene.emit(user_data)

func request_quit_f() -> void:
  request_quit.emit()
