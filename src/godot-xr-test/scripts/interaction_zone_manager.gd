class_name InteractionZoneManager extends Node3D

# Re-export the signals from HandInteractionManager
signal pinch_started(hand_name)
signal pinch_ended(hand_name)
signal grab_started(hand_name)
signal grab_ended(hand_name)
signal hand_pose_started(hand_name)
signal hand_pose_ended(hand_name)

# References
@export var xr_camera: XRCamera3D
@export var hand_interaction_manager: HandInteractionManager
## Constant radius of the cylinder
@export var cylinder_radius: float = 0.4

## How far the cylinder extends
@export var cylinder_length: float = 1.5

## Minimum distance from camera
@export var cylinder_min_distance: float = 0.15

var _hands_in_zone: Dictionary = {"left": false, "right": false}
var _active_interactions: Dictionary = {"left": null, "right": null}

func _ready() -> void:
  # Connect to hand interaction manager
  if hand_interaction_manager:
    _connect_to_hand_manager()
  else:
    push_error("InteractionZoneManager: No HandInteractionManager assigned!")
  
  print("Interaction Zone Manager initialized")

func _process(_delta) -> void:
  if !xr_camera:
    return
  
  # Update hand positions and check if in zone
  _update_hands_in_zone()

func _update_hands_in_zone() -> void:
  if !hand_interaction_manager:
    return
  
  # Check each hand position using our cylinder-based detection
  _check_hand_in_zone("left")
  _check_hand_in_zone("right")

func _check_hand_in_zone(hand_name: String) -> void:
  if !xr_camera || !hand_interaction_manager:
    return
      
  # Get the hand position
  var hand_position = hand_interaction_manager.get_hand_position(hand_name)
  if hand_position == Vector3.ZERO:
    # Hand position not available
    return
  
  # Get camera position and direction
  var cam_pos = xr_camera.global_transform.origin
  var cam_dir = -xr_camera.global_transform.basis.z.normalized()
  
  # 1. Calculate vector from camera to hand
  var cam_to_hand = hand_position - cam_pos
  
  # 2. Calculate distance along camera direction
  var projected_distance = cam_to_hand.dot(cam_dir)
  
  # If hand is behind the camera or too close, it's outside
  if projected_distance < cylinder_min_distance:
    _update_hand_zone_state(hand_name, false)
    return
  
  # If hand is too far away, it's outside
  if projected_distance > (cylinder_min_distance + cylinder_length):
    _update_hand_zone_state(hand_name, false)
    return
  
  # 3. Calculate perpendicular distance from cylinder axis
  var projected_point = cam_pos + (cam_dir * projected_distance)
  var perpendicular_distance = hand_position.distance_to(projected_point)
  
  # 4. Check if hand is within the cylinder radius (constant throughout)
  var is_in_zone = perpendicular_distance <= cylinder_radius
  
  # Update the hand state
  _update_hand_zone_state(hand_name, is_in_zone)

func _update_hand_zone_state(hand_name: String, is_in_zone: bool) -> void:
  # Only update if state changed
  if is_in_zone != _hands_in_zone.get(hand_name, false):
    _hands_in_zone[hand_name] = is_in_zone
    if is_in_zone:
      print(hand_name, " hand entered interaction zone")
    else:
      print(hand_name, " hand exited interaction zone")

func _connect_to_hand_manager() -> void:
  # Connect to hand interaction manager signals
  hand_interaction_manager.pinch_started.connect(_filter_pinch_started)
  hand_interaction_manager.pinch_ended.connect(_filter_pinch_ended)
  hand_interaction_manager.grab_started.connect(_filter_grab_started)
  hand_interaction_manager.grab_ended.connect(_filter_grab_ended)
  hand_interaction_manager.hand_pose_started.connect(_filter_hand_pose_started)
  hand_interaction_manager.hand_pose_ended.connect(_filter_hand_pose_ended)

func register_interaction(hand_name: String, interactable: InteractableObject) -> void:
  _active_interactions[hand_name] = interactable
  print("Registered interaction for " + hand_name + " hand with object: " + interactable.name)

func clear_interaction(hand_name: String) -> void:
  if _active_interactions[hand_name]:
    print("Cleared interaction for " + hand_name + " hand")
    _active_interactions[hand_name] = null

func is_hand_available(hand_name: String) -> bool:
  return _active_interactions[hand_name] == null

# Signal filters
func _filter_pinch_started(hand_name: String) -> void:
  # Only emit if the hand is in the interaction zone and not currently active
  if _hands_in_zone.get(hand_name, false) && is_hand_available(hand_name):
    emit_signal("pinch_started", hand_name)
  else:
    if !_hands_in_zone.get(hand_name, false):
      print("Ignoring pinch start from " + hand_name + " hand (outside interaction zone)")
    else:
      print("Ignoring pinch start from " + hand_name + " hand (already interacting)")

func _filter_pinch_ended(hand_name: String) -> void:
  # Always emit pinch ended, which will allow ending interactions
  emit_signal("pinch_ended", hand_name)
  # Clear interaction when pinch ends
  clear_interaction(hand_name)

func _filter_grab_started(hand_name: String) -> void:
  # Only emit if the hand is in the interaction zone and not currently active
  if _hands_in_zone.get(hand_name, false) && is_hand_available(hand_name):
    emit_signal("grab_started", hand_name)
  else:
    if !_hands_in_zone.get(hand_name, false):
      print("Ignoring grab start from " + hand_name + " hand (outside interaction zone)")
    else:
      print("Ignoring grab start from " + hand_name + " hand (already interacting)")

func _filter_grab_ended(hand_name: String) -> void:
  # Always emit grab ended, which will allow ending interactions
  emit_signal("grab_ended", hand_name)
  # Clear interaction when grab ends
  clear_interaction(hand_name)

func _filter_hand_pose_started(hand_name: String) -> void:
  # Only emit if the hand is in the interaction zone and not currently active
  if _hands_in_zone.get(hand_name, false) && is_hand_available(hand_name):
    emit_signal("hand_pose_started", hand_name)
  else:
    if !_hands_in_zone.get(hand_name, false):
      print("Ignoring hand pose start from " + hand_name + " hand (outside interaction zone)")
    else:
      print("Ignoring hand pose start from " + hand_name + " hand (already interacting)")

func _filter_hand_pose_ended(hand_name: String) -> void:
  # Always emit hand pose ended
  emit_signal("hand_pose_ended", hand_name)
  # Clear interaction when hand pose ends
  clear_interaction(hand_name)
