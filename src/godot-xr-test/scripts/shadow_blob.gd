class_name ShadowBlob extends Node3D

## The node where the shadow sprite should be parented
@export var shadow_sprite_target: Node3D

## The texture to be used for the shadow projection
@export var shadow_texture: Texture2D

## Maximum distance the shadow can be cast
@export var max_distance: float = 2.0

## Size of the shadow in the X and Z axes
@export var shadow_size: Vector2 = Vector2(0.5, 0.5)

var _shadow_sprite: Sprite3D

func _ready() -> void:
  # Create shadow sprite
  _shadow_sprite = Sprite3D.new()
  _shadow_sprite.texture = shadow_texture
  _shadow_sprite.pixel_size = 0.01
  _shadow_sprite.modulate.a = 0.0
  _shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
  _shadow_sprite.double_sided = false
  _shadow_sprite.axis = Vector3.AXIS_Y
  _shadow_sprite.scale = Vector3(shadow_size.x, 1.0, shadow_size.y)
  if shadow_sprite_target:
    shadow_sprite_target.add_child.call_deferred(_shadow_sprite)
  else:
    add_child(_shadow_sprite)
    
func _process(delta: float) -> void:
  var raycast_result = _cast_downward_ray()
  if !raycast_result.is_empty():
    var hit_point = raycast_result.position
    _shadow_sprite.global_position = hit_point + Vector3(0, 0.01, 0)
    _shadow_sprite.global_rotation = Vector3(0.0, _shadow_sprite.global_rotation.y, 0.0)
    
    # Adjust shadow opacity based on distance
    var distance = global_position.y - hit_point.y
    var opacity_factor = clamp(1.0 - (distance / max_distance), 0.0, 1.0)
    _shadow_sprite.modulate.a = lerp(_shadow_sprite.modulate.a, opacity_factor, delta * 10.0)
  else:
    _shadow_sprite.modulate.a = lerp(_shadow_sprite.modulate.a, 0.0, delta * 2.0)

func _cast_downward_ray():
  var space_state = get_world_3d().direct_space_state

  var from = global_transform.origin
  from.y += 0.05 # Offset it a bit, so the Raycast hits the ground even if the node is at zero positon
  var to = from - Vector3.UP * max_distance

  var query = PhysicsRayQueryParameters3D.create(from, to)
  query.collision_mask = 0b10000
  var result = space_state.intersect_ray(query)

  return result
