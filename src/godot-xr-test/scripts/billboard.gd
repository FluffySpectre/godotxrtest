class_name Billboard extends Node

var _parent: Node3D
var _camera: Camera3D

func _ready():
  # Wait one frame to make sure the scene is fully loaded
  await get_tree().process_frame
  
  _parent = get_parent() as Node3D
  _camera = get_viewport().get_camera_3d()

func _process(_delta):
  if _camera:
    # Make this node look at the camera's position
    _parent.look_at(_camera.global_position, Vector3.UP)
    
    # Flip to face the camera
    _parent.rotate_object_local(Vector3.UP, PI)
