class_name ObjectGatherer extends Node

signal gathering_complete

# Configuration
@export var radius: float = 1.0  # Distance from player
@export var height_offset: float = -0.5  # Height relative to player (eye level)
@export var arc_degrees: float = 180.0  # How much of a circle to use (180 = semicircle in front)
@export var spacing_degrees: float = 45.0  # Spacing between objects
@export var max_objects: int = 5  # Maximum objects to gather at once

# References
@export var xr_origin: XROrigin3D

# Animation
@export var animate_movement: bool = true
@export var animation_duration: float = 0.5

func gather_objects() -> void:
  if !xr_origin:
    xr_origin = XRRig.instance
    if !xr_origin:
      print("ERROR: Cannot find XR Origin node")
      return
  
  # Get player position and forward direction
  var camera = xr_origin.get_node("XRCamera3D")
  var player_position = camera.global_position
  var forward_direction = -camera.global_transform.basis.z
  forward_direction.y = 0  # Zero out the Y component to keep it horizontal
  forward_direction = forward_direction.normalized()
  
  # Get all top-level InteractableObjects in the scene
  var interactable_objects = []
  var root = get_tree().root
  var main_scene = root.get_child(root.get_child_count() - 1)
  
  # Find all direct children of the main scene that are InteractableObjects
  for child in main_scene.get_children():
    if child is InteractableObject:
      interactable_objects.append(child)
  
  # If we don't have any objects, exit early
  if interactable_objects.size() == 0:
    print("No InteractableObjects found to gather")
    return
  
  # Limit to max objects if needed
  if interactable_objects.size() > max_objects:
    interactable_objects = interactable_objects.slice(0, max_objects)
  
  # Calculate positions in an arc around the player
  var object_count = interactable_objects.size()
  var right_vector = forward_direction.cross(Vector3.UP)
  
  # Determine how to distribute objects
  var start_angle = -arc_degrees / 2.0
  var angle_increment = min(spacing_degrees, arc_degrees / max(1, object_count - 1))
  
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
      _animate_object_movement(obj, target_position)
    else:
      obj.global_position = target_position
  
  # Emit signal when done
  emit_signal("gathering_complete")

func _animate_object_movement(obj: InteractableObject, target_position: Vector3) -> void:
  # Create a tween to animate the movement
  var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
  tween.tween_property(obj, "global_position", target_position, animation_duration)
