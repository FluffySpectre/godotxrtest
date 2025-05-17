extends Node

@export var scene_manager: OpenXRFbSceneManager

func _ready() -> void:
  scene_manager.openxr_fb_scene_data_missing.connect(_scene_data_missing)
  scene_manager.openxr_fb_scene_capture_completed.connect(_scene_capture_completed)
  
func _scene_data_missing() -> void:
  print("RoomScan: Scene data missing. Requesting scene capture...")
  scene_manager.request_scene_capture()

func _scene_capture_completed(success: bool) -> void:
  if success == false:
    return
  
  # Delete any existing anchors, since the user may have changed them.
  if scene_manager.are_scene_anchors_created():
    scene_manager.remove_scene_anchors()

  # Create scene_anchors for the freshly captured scene
  scene_manager.create_scene_anchors()

  print("RoomScan: Scene capture complete!")

func _on_xr_session_begun() -> void:
  print("RoomScan: XR Session begun")
  scene_manager.request_scene_capture()
