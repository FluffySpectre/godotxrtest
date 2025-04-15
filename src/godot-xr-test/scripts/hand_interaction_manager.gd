class_name HandInteractionManager extends Node3D

signal pinch_started(hand_name)
signal pinch_ended(hand_name)
signal grab_started(hand_name)
signal grab_ended(hand_name)
signal hand_pose_started(hand_name)
signal hand_pose_ended(hand_name)

# References to hand controllers
@export var left_controller: XRController3D
@export var right_controller: XRController3D

# Tracking states
var left_pinching = false
var right_pinching = false
var left_grabbing = false
var right_grabbing = false
var left_hand_pose_active = false
var right_hand_pose_active = false

# Gesture thresholds
const PINCH_THRESHOLD = 0.7
const GRAB_THRESHOLD = 0.8
const GRAB_OPEN_FOR_HAND = 0.15
const GRAB_CLOSE_FOR_HAND = 0.3

# Action paths for hand tracking
const LEFT_PINCH_PATH = "pinch"
const RIGHT_PINCH_PATH = "pinch"
const LEFT_GRAB_PATH = "grip" 
const RIGHT_GRAB_PATH = "grip"

func _process(_delta) -> void:
  _process_hand_gestures()
  _check_hand_poses()

func _process_hand_gestures() -> void:
  # Get pinch and grab values using the OpenXR action map
  var left_pinch_value = _get_action_value(left_controller, LEFT_PINCH_PATH)
  var right_pinch_value = _get_action_value(right_controller, RIGHT_PINCH_PATH)  
  var left_grab_value = _get_action_value(left_controller, LEFT_GRAB_PATH)
  var right_grab_value = _get_action_value(right_controller, RIGHT_GRAB_PATH)
  
  # Process pinch gestures
  _process_pinch_gesture("left", left_pinch_value)
  _process_pinch_gesture("right", right_pinch_value)
  
  # Process grab gestures
  _process_grab_gesture("left", left_grab_value)
  _process_grab_gesture("right", right_grab_value)

func _check_hand_poses() -> void:
  _check_hand_pose("left")
  _check_hand_pose("right")

func _check_hand_pose(hand_name: String) -> void:
  var controller = left_controller if hand_name == "left" else right_controller
  var currently_active = hand_name == "left" and left_hand_pose_active or hand_name == "right" and right_hand_pose_active
  
  if not controller:
    return
  
  # Get the grab value to ensure the hand is open
  var grab_value = _get_action_value(controller, LEFT_GRAB_PATH if hand_name == "left" else RIGHT_GRAB_PATH)
  var hand_is_open = (!currently_active and grab_value <= GRAB_OPEN_FOR_HAND) || (currently_active and grab_value <= GRAB_CLOSE_FOR_HAND)

  var back_of_hand_facing_camera = hand_is_open

  # Detect hand pose started
  if back_of_hand_facing_camera and not currently_active:
    if hand_name == "left":
      left_hand_pose_active = true
    else:
      right_hand_pose_active = true
    emit_signal("hand_pose_started", hand_name)
    print("Hand back pose started: ", hand_name)
  
  # Detect hand pose ended
  elif not back_of_hand_facing_camera and currently_active:
    if hand_name == "left":
      left_hand_pose_active = false
    else:
      right_hand_pose_active = false
    emit_signal("hand_pose_ended", hand_name)
    print("Hand back pose ended: ", hand_name)

func _get_action_value(controller, action_path) -> float:
  if controller:
    # Try to get float input
    if controller.has_method("get_float"):
      return controller.get_float(action_path)
  return 0.0

func _process_pinch_gesture(hand_name, pinch_value) -> void:
  var currently_pinching = (hand_name == "left" and left_pinching) or (hand_name == "right" and right_pinching)
  
  # Detect pinch start
  if pinch_value >= PINCH_THRESHOLD and not currently_pinching:
    if hand_name == "left":
      left_pinching = true
    else:
      right_pinching = true
    emit_signal("pinch_started", hand_name)
  
  # Detect pinch end
  elif pinch_value < PINCH_THRESHOLD and currently_pinching:
    if hand_name == "left":
      left_pinching = false
    else:
      right_pinching = false
    emit_signal("pinch_ended", hand_name)

func _process_grab_gesture(hand_name, grab_value) -> void:
  var currently_grabbing = (hand_name == "left" and left_grabbing) or (hand_name == "right" and right_grabbing)
  
  # Detect grab start
  if grab_value >= GRAB_THRESHOLD and not currently_grabbing:
    if hand_name == "left":
      left_grabbing = true
    else:
      right_grabbing = true
    emit_signal("grab_started", hand_name)
  
  # Detect grab end
  elif grab_value < GRAB_THRESHOLD and currently_grabbing:
    if hand_name == "left":
      left_grabbing = false
    else:
      right_grabbing = false
    emit_signal("grab_ended", hand_name)

# Get the position of a specific hand in world space
func get_hand_position(hand_name) -> Vector3:
  var controller = left_controller if hand_name == "left" else right_controller
  return controller.global_position

# Get the global transform of a specific hand
func get_hand_transform(hand_name) -> Transform3D:
  var controller = left_controller if hand_name == "left" else right_controller
  return controller.global_transform
