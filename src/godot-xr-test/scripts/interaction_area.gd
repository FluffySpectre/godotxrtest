class_name InteractionArea extends Area3D

@export var interaction_area_material: Material

@onready var _parent = get_parent() as Node3D
@onready var _interaction_area_collision: CollisionShape3D = $CollisionShape3D

var _wireframe_box: WireframeBox

func _ready() -> void:
  _setup_wireframe_box()
  
  set_highlight(false)

func scale_area(scale_value: float) -> void:
  _parent.scale = Vector3(scale_value, scale_value, scale_value)

func rotate_area(rotate_value: Vector3) -> void:
  _parent.rotation = rotate_value

func is_position_in_area(pos: Vector3) -> bool:    
  if !_interaction_area_collision || !_interaction_area_collision.shape:
    return false
  
  var space_state = get_world_3d().direct_space_state
  var query = PhysicsPointQueryParameters3D.new()
  query.position = pos
  query.collision_mask = collision_mask
  query.collide_with_areas = true
  
  var results = space_state.intersect_point(query)
  
  for result in results:
    if result.collider == self:
      return true
  
  return false

func set_highlight(highlight: bool) -> void:
  _wireframe_box.visible = highlight

func _setup_wireframe_box() -> void:
  var collision_shape: BoxShape3D = _interaction_area_collision.shape as BoxShape3D
  _wireframe_box = WireframeBox.new(interaction_area_material, collision_shape.size)
  add_child(_wireframe_box)
  _wireframe_box.global_position = _interaction_area_collision.global_position
