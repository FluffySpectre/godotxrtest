class_name InteractionArea extends Area3D

@onready var _parent = get_parent() as Node3D
@onready var interaction_area_collision: CollisionShape3D = $CollisionShape3D
@onready var interaction_area_mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
  set_highlight(false)

func scale_area(scale_value: float) -> void:
  _parent.scale = Vector3(scale_value, scale_value, scale_value)

func rotate_area(rotate_value: Vector3) -> void:
  _parent.rotation = rotate_value

func is_position_in_area(position: Vector3) -> bool:    
    if not interaction_area_collision or not interaction_area_collision.shape:
        return false
        
    # Get the shape
    var box_shape = interaction_area_collision.shape as BoxShape3D
    if not box_shape:
        return false
    
    # Convert the position to local space
    var local_position = global_transform.affine_inverse() * position
    
    # Get the box size (half-extents)
    var box_size = box_shape.size / 2
    
    # Check if the position is inside the box
    return (
        abs(local_position.x) <= box_size.x and
        abs(local_position.y) <= box_size.y and
        abs(local_position.z) <= box_size.z
    )

func set_highlight(highlight: bool) -> void:
  interaction_area_mesh.visible = highlight
