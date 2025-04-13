class_name InteractionArea extends Area3D

@export var interaction_area_material: Material

@onready var _parent = get_parent() as Node3D
@onready var _interaction_area_collision: CollisionShape3D = $CollisionShape3D
@onready var _interaction_area_mesh: MeshInstance3D = $MeshInstance3D

var _wireframe_box: WireframeBox

func _ready() -> void:
  _setup_wireframe_box()
  
  set_highlight(false)

func scale_area(scale_value: float) -> void:
  _parent.scale = Vector3(scale_value, scale_value, scale_value)

func rotate_area(rotate_value: Vector3) -> void:
  _parent.rotation = rotate_value

func is_position_in_area(pos: Vector3) -> bool:    
  if not _interaction_area_collision or not _interaction_area_collision.shape:
    return false
      
  # Get the shape
  var box_shape = _interaction_area_collision.shape as BoxShape3D
  if not box_shape:
    return false
  
  # Convert the position to local space
  var local_position = global_transform.affine_inverse() * pos
  
  # Get the box size (half-extents)
  var box_size = box_shape.size / 2
  
  # Check if the position is inside the box
  return (
    abs(local_position.x) <= box_size.x and
    abs(local_position.y) <= box_size.y and
    abs(local_position.z) <= box_size.z
  )

func set_highlight(highlight: bool) -> void:
  #_interaction_area_mesh.visible = highlight
  _wireframe_box.visible = highlight

func _setup_wireframe_box() -> void:
  _wireframe_box = WireframeBox.new(interaction_area_material, _interaction_area_mesh.scale)
  add_child(_wireframe_box)
  _wireframe_box.global_position = _interaction_area_mesh.global_position
