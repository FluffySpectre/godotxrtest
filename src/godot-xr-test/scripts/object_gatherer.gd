class_name ObjectGatherer extends Node

signal gathering_complete

## Distance from player
@export var radius: float = 1.0

## Height relative to player (eye level)
@export var height_offset: float = -0.5

## How much of a circle to use (180 = semicircle in front)
@export var arc_degrees: float = 180.0

## Spacing between objects
@export var spacing_degrees: float = 45.0

## Maximum objects to gather at once
@export var max_objects: int = 5

## Animate object movement or directly set position (teleport)
@export var animate_movement: bool = true

## How long the animation takes
@export var animation_duration: float = 0.5

var _camera: Node3D

func gather_objects() -> void:
  if !_camera:
    _camera = get_viewport().get_camera_3d()
    if !_camera:
      print("ERROR: Cannot find camera")
      return
  
  # Get player position and forward direction
  var player_position = _camera.global_position
  var forward_direction = -_camera.global_transform.basis.z
  forward_direction.y = 0
  forward_direction = forward_direction.normalized()
  
  # Find all InteractableObjects which are in group "interactable"
  var interactable_objects = []
  var interactables_in_group = get_tree().get_nodes_in_group("interactable")
  for group_object in interactables_in_group:
    if valid_interactable(group_object):
      interactable_objects.append(group_object)
  
  # If we don't have any objects, exit early
  if interactable_objects.size() == 0:
    print("No InteractableObjects found to gather")
    return
  
  # Limit to max objects if needed
  if interactable_objects.size() > max_objects:
    interactable_objects = interactable_objects.slice(0, max_objects)
  
  # Calculate positions in an arc around the player
  var object_count = interactable_objects.size()
  
  # Determine how to distribute objects
  var angle_increment = min(spacing_degrees, arc_degrees / max(1, object_count - 1))
  
  # Calculate total angle span and center it
  var total_angle_span = 0
  if object_count > 1:
    total_angle_span = angle_increment * (object_count - 1)
  var start_angle = -total_angle_span / 2.0
  
  # Position each object
  for i in range(object_count):
    var obj = interactable_objects[i]
    
    # Calculate angle for this object
    var angle_rad = deg_to_rad(start_angle + (i * angle_increment))
    
    # Calculate position at this angle
    var offset = forward_direction.rotated(Vector3.UP, angle_rad) * radius
    var target_position = player_position + offset
    target_position.y = player_position.y + height_offset
    
    # Either animate or directly set the position
    if animate_movement:
      animate_object_movement(obj, target_position)
    else:
      obj.global_position = target_position
  
  # Emit signal when done
  emit_signal("gathering_complete")

func valid_interactable(object: InteractableObject) -> bool:
  return (object is InteractableObject 
      && !(object.has_meta("not_gatherable") && object.get_meta("not_gatherable"))
      && !object.is_snapped_to_zone)

func animate_object_movement(obj: InteractableObject, target_position: Vector3) -> void:
  var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
  tween.tween_property(obj, "global_position", target_position, animation_duration)
