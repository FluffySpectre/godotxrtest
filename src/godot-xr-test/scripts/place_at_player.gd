class_name PlaceAtPlayer extends Node

@onready var _parent: Node3D = get_parent() as Node3D

func _ready() -> void:
  XRManager.instance.pose_recentered.connect(_on_pose_recentered)

func _exit_tree() -> void:
  XRManager.instance.pose_recentered.disconnect(_on_pose_recentered)

func _process(_delta: float) -> void:
  # Wait 3 frames to give the XROrigin time to initialize
  await get_tree().process_frame
  await get_tree().process_frame
  await get_tree().process_frame
  
  place()

  # Execute only once
  process_mode = Node.PROCESS_MODE_DISABLED

func place() -> void:
  var cam_position: Vector3 = XRRig.instance.xr_camera.global_position
  var cam_rotation: Vector3 = XRRig.instance.xr_camera.global_rotation
  
  _parent.global_position = Vector3(cam_position.x, 0.0, cam_position.z)
  _parent.global_rotation = Vector3(0.0, cam_rotation.y, 0.0)

func _on_pose_recentered() -> void:
  place()
