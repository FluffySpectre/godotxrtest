class_name RotaryKnob extends Node3D

signal step_changed(step_index: int)

@export_group("Knob Settings")
@export var step_count: int = 2
@export var step_angle: float = 45.0  # Degrees per step
@export var min_angle: float = -180.0  # Minimum rotation angle
@export var max_angle: float = 180.0   # Maximum rotation angle
@export var snap_to_steps: bool = true
@export var rotation_threshold: float = 0.01  # Radians of hand rotation before knob starts rotating
@export var rotation_sensitivity: float = 50.0

@export_group("Feedback")
@export var step_sound: AudioStream
@export var grab_sound: AudioStream
@export var release_sound: AudioStream

@export_group("Visual")
@export var knob_node: Node3D

# References
@onready var _interaction_area: InteractionArea = $InteractionArea/InteractionAreaInner
@onready var _sound_player: AudioStreamPlayer3D = $SoundPlayer

# State variables
var _current_step: int = 0
var _current_angle: float = 0.0
var _is_grabbed: bool = false
var _grabbing_hand: String = ""
var _initial_hand_rotation: float
var _initial_knob_angle: float
var _last_step: int = -1
var _rotation_started: bool = false

func _ready() -> void:
  _current_angle = max_angle
  _calculate_step_angles()
  
  # Connect to interaction signals
  InteractionZoneManager.instance.pinch_started.connect(_on_pinch_started)
  InteractionZoneManager.instance.pinch_ended.connect(_on_pinch_ended)
  
  # Set initial rotation
  _update_knob_rotation()

func _calculate_step_angles() -> void:
  if step_count <= 1:
    return
    
  var total_range = max_angle - min_angle
  step_angle = total_range / (step_count - 1)

func _process(_delta: float) -> void:
  if _is_grabbed:
    _update_rotation()

func _on_pinch_started(hand_name: String) -> void:
  if _is_grabbed:
    return
    
  # Check if hand is near the knob
  var hand_position = _get_hand_position(hand_name)
  if hand_position == Vector3.ZERO:
    return
  
  if _interaction_area.is_position_in_area(hand_position):
    _start_grab(hand_name)

func _on_pinch_ended(hand_name: String) -> void:
  if _is_grabbed && _grabbing_hand == hand_name:
    _end_grab()

func _start_grab(hand_name: String) -> void:
  if !InteractionZoneManager.instance.register_interaction(hand_name, null, true):
    return
    
  _is_grabbed = true
  _grabbing_hand = hand_name
  _initial_hand_rotation = _get_hand_rotation(hand_name)
  _initial_knob_angle = _current_angle
  _rotation_started = false
  
  if _sound_player && grab_sound:
    _sound_player.stream = grab_sound
    _sound_player.play()
  
  print("RotaryKnob grabbed by ", hand_name, " hand")

func _end_grab() -> void:
  if !_is_grabbed:
    return
    
  InteractionZoneManager.instance.clear_interaction(_grabbing_hand)
  
  # Snap to nearest step if enabled
  if snap_to_steps:
    _snap_to_nearest_step()
  
  # Play release sound
  if _sound_player && release_sound:
    _sound_player.stream = release_sound
    _sound_player.play()
  
  _is_grabbed = false
  _grabbing_hand = ""
  _rotation_started = false
  
  print("RotaryKnob released")

func _update_rotation() -> void:
  if !_is_grabbed || _grabbing_hand == "":
    return
    
  var current_hand_rotation = _get_hand_rotation(_grabbing_hand)
  if current_hand_rotation == 0.0 && _initial_hand_rotation == 0.0:
    return
    
  # Calculate rotation delta
  var rotation_delta = current_hand_rotation - _initial_hand_rotation
  
  # Handle angle wrapping
  if rotation_delta > PI:
    rotation_delta -= 2 * PI
  elif rotation_delta < -PI:
    rotation_delta += 2 * PI
  
  # Check if we've rotated enough to start turning the knob
  if !_rotation_started && abs(rotation_delta) < rotation_threshold:
    return
    
  if !_rotation_started:
    _rotation_started = true
    # Reset initial values when rotation threshold is crossed
    _initial_hand_rotation = current_hand_rotation
    _initial_knob_angle = _current_angle
    rotation_delta = 0.0
  
  # Apply sensitivity and calculate new angle
  var rotation_change = rad_to_deg(rotation_delta) * rotation_sensitivity
  var new_angle = _initial_knob_angle + rotation_change
  
  # Clamp to min/max range
  new_angle = clamp(new_angle, min_angle, max_angle)
  
  # Update current angle
  _current_angle = new_angle
  
  # Calculate current step
  var new_step = _angle_to_step(_current_angle)
  
  # Check for step change
  if new_step != _last_step && _last_step != -1:
    _on_step_changed(new_step)
  
  _last_step = new_step
  _current_step = new_step
  
  # Update visual rotation
  _update_knob_rotation()

func _get_hand_rotation(hand_name: String) -> float:
  var controller: XRController3D = null
  
  if hand_name == "left":
    controller = HandInteractionManager.instance.left_controller
  elif hand_name == "right":
    controller = HandInteractionManager.instance.right_controller
  
  if !controller:
    return 0.0
  
  # Get the Y rotation (twist around the forearm axis) for wrist rotation
  var hand_rotation = controller.global_rotation
  return hand_rotation.y

func _angle_to_step(angle: float) -> int:
  if step_count <= 1:
    return 0
    
  var normalized_angle = (angle - min_angle) / (max_angle - min_angle)
  var step = round(normalized_angle * (step_count - 1))
  return clamp(step, 0, step_count - 1)

func _step_to_angle(step: int) -> float:
  if step_count <= 1:
    return 0.0
    
  var normalized_step = float(step) / float(step_count - 1)
  return min_angle + normalized_step * (max_angle - min_angle)

func _snap_to_nearest_step() -> void:
  var target_step = _angle_to_step(_current_angle)
  var target_angle = _step_to_angle(target_step)
  
  # Animate to target angle
  var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
  tween.tween_method(_set_angle_and_update, _current_angle, target_angle, 0.2)
  
  _current_step = target_step
  _current_angle = target_angle

func _set_angle_and_update(angle: float) -> void:
  _current_angle = angle
  _update_knob_rotation()

func _update_knob_rotation() -> void:
  if knob_node:
    knob_node.rotation_degrees.y = _current_angle

func _on_step_changed(new_step: int) -> void:
  # Play step sound
  if _sound_player && step_sound:
    _sound_player.stream = step_sound
    _sound_player.play()
  
  emit_signal("step_changed", new_step)
  
  print("RotaryKnob step changed to: ", new_step)
  
func _get_hand_position(hand_name: String) -> Vector3:
  if hand_name == "left" && HandInteractionManager.instance.left_controller_pointer:
    return HandInteractionManager.instance.left_controller_pointer.global_position
  elif hand_name == "right" && HandInteractionManager.instance.right_controller_pointer:
    return HandInteractionManager.instance.right_controller_pointer.global_position
  return Vector3.ZERO

func set_step(step: int) -> void:
  step = clamp(step, 0, step_count - 1)
  _current_step = step
  _current_angle = _step_to_angle(step)
  _update_knob_rotation()
  emit_signal("step_changed", step)

func set_enabled(enabled: bool) -> void:
  _interaction_area.monitoring = enabled
  _interaction_area.monitorable = enabled
