class_name InteractableObject extends Node3D

# Signals
signal pinch_move_started(hand_name)
signal pinch_move_ended(hand_name)
signal scaling_started
signal scaling_ended

# Properties
@export var can_scale: bool = true
@export var can_move: bool = true
@export var min_scale: float = 0.1
@export var max_scale: float = 2.0
@export var snap_to_ground: bool = false
@export var movement_threshold: float = 0.05  # Distance in meters before movement starts

# References
@onready var model = $Model
@onready var hand_tracking_manager: HandInteractionManager = $"/root/Main/XROrigin3D/HandInteractionManager"
@onready var ground_detection: GroundDetection = $GroundDetection

# State variables
var is_moving: bool = false            # Tracking if we're in movement mode
var is_scaling: bool = false           # Tracking if we're in scaling mode
var movement_started: bool = false     # Tracking if we've crossed the movement threshold
var active_hand: String = ""           # Which hand is controlling movement
var initial_pinch_position: Vector3    # Starting position of the pinching hand
var initial_object_position: Vector3   # Starting position of the object
var initial_distance: float = 0.0      # Starting distance between hands for scaling
var initial_scale: float = 1.0         # Starting scale of the model
var hands_pinching: Dictionary = {"left": false, "right": false}
var cumulative_movement: float = 0.0
var last_hand_positions: Dictionary = {"left": Vector3.ZERO, "right": Vector3.ZERO}

func _ready():
    # Connect signals from hand tracking manager
    hand_tracking_manager.pinch_started.connect(_on_pinch_started)
    hand_tracking_manager.pinch_ended.connect(_on_pinch_ended)
    
    # Store initial scale
    if model:
        initial_scale = model.scale.x
    
    print("Interactable object initialized: ", name)
    print("Can scale: ", can_scale, ", Can move: ", can_move)
    print("Movement threshold: ", movement_threshold)

func _process(delta):
    # Update hand positions
    _update_hand_positions()
    
    # Check if we need to switch to scaling mode (but only if movement hasn't started yet)
    _check_for_mode_switch()
    
    # Handle the active mode
    if is_scaling and can_scale:
        _update_scale()
    elif is_moving and can_move:
        _update_position()
    
    # Apply ground snapping when not being manipulated
    if snap_to_ground and !is_moving:
        _snap_to_ground()

func _update_hand_positions():
    # Keep track of hand positions for calculations
    if hand_tracking_manager.left_controller:
        last_hand_positions["left"] = hand_tracking_manager.left_controller.global_transform.origin
    if hand_tracking_manager.right_controller:
        last_hand_positions["right"] = hand_tracking_manager.right_controller.global_transform.origin

func _check_for_mode_switch():
    # Only allow switching to scaling if we're not in active movement mode
    # (we're in pre-movement state where the threshold hasn't been crossed yet)
    if hands_pinching["left"] and hands_pinching["right"] and !is_scaling and can_scale:
        if is_moving and !movement_started:
            # We're in pre-movement state, so we can still switch to scaling
            _end_movement()
            _start_scaling()
        elif !is_moving:
            # Not in movement mode at all, so we can start scaling
            _start_scaling()

func _on_pinch_started(hand_name):
    print("Pinch started: ", hand_name)
    hands_pinching[hand_name] = true
    
    # If both hands are pinching, check if we can start scaling mode
    if hands_pinching["left"] and hands_pinching["right"] and can_scale:
        # Only start scaling if we're not in active movement mode
        if !is_moving or (is_moving and !movement_started):
            print("Starting scaling mode")
            if is_moving:
                _end_movement()
            _start_scaling()
        else:
            print("Movement already active, ignoring scaling attempt")
    # If only one hand is pinching and we're not in any active mode
    elif !is_scaling and !is_moving and can_move:
        print("Preparing movement mode with hand: ", hand_name)
        _start_movement(hand_name)

func _on_pinch_ended(hand_name):
    print("Pinch ended: ", hand_name)
    hands_pinching[hand_name] = false
    
    # If either hand stops pinching during scaling, end scaling mode
    if is_scaling and (!hands_pinching["left"] or !hands_pinching["right"]):
        print("Ending scaling mode")
        _end_scaling()
    
    # If the active hand stops pinching during movement, end movement mode
    if is_moving and active_hand == hand_name:
        print("Ending movement mode")
        _end_movement()

func _start_movement(hand_name):
    is_moving = true
    active_hand = hand_name
    movement_started = false
    cumulative_movement = 0.0
    
    # Store initial positions
    initial_pinch_position = last_hand_positions[hand_name]
    initial_object_position = global_transform.origin
    
    print("Movement prepared with hand: ", hand_name)
    # We don't emit the signal yet, only when movement actually starts

func _end_movement():
    if !is_moving:
        return
        
    is_moving = false
    movement_started = false
    var previous_hand = active_hand
    active_hand = ""
    
    print("Movement ended")
    emit_signal("pinch_move_ended", previous_hand)

func _start_scaling():
    # Don't start scaling if we don't have positions for both hands
    if !last_hand_positions.has("left") or !last_hand_positions.has("right"):
        print("Cannot start scaling: missing hand positions")
        return
        
    is_scaling = true
    
    # Get hand positions
    var left_hand_pos = last_hand_positions["left"]
    var right_hand_pos = last_hand_positions["right"]
    
    # Record initial distance and scale
    initial_distance = left_hand_pos.distance_to(right_hand_pos)
    if model:
        initial_scale = model.scale.x
    
    print("Scaling started with initial distance: ", initial_distance)
    emit_signal("scaling_started")

func _end_scaling():
    if !is_scaling:
        return
        
    is_scaling = false
    print("Scaling ended")
    emit_signal("scaling_ended")

func _update_position():
    if !is_moving or !active_hand or !last_hand_positions.has(active_hand):
        return
        
    var current_hand_position = last_hand_positions[active_hand]
    var movement_vector = current_hand_position - initial_pinch_position
    
    # Calculate total movement distance
    if !movement_started:
        cumulative_movement = movement_vector.length()  # Use absolute distance, not cumulative
        
        # Check if we've moved past the threshold
        if cumulative_movement >= movement_threshold:
            print("Movement threshold reached: ", cumulative_movement, " >= ", movement_threshold)
            movement_started = true
            emit_signal("pinch_move_started", active_hand)  # Now emit the signal
    
    # Only update position if we've passed the movement threshold
    if movement_started:
        global_transform.origin = initial_object_position + movement_vector

func _update_scale():
    if !is_scaling or !model:
        return
        
    # Get current hand positions
    var left_hand_pos = last_hand_positions["left"]
    var right_hand_pos = last_hand_positions["right"]
    
    # Calculate new distance and scale factor
    var current_distance = left_hand_pos.distance_to(right_hand_pos)
    var scale_factor = current_distance / initial_distance
    
    # Calculate new scale and clamp to min/max
    var new_scale = initial_scale * scale_factor
    new_scale = clamp(new_scale, min_scale, max_scale)
    
    # Apply uniform scaling
    model.scale = Vector3(new_scale, new_scale, new_scale)

func _snap_to_ground():
    # Cast a ray downward from the object
    if ground_detection and ground_detection.is_colliding():
        var collision_point = ground_detection.get_collision_point()
        var current_pos = global_transform.origin
        # Only adjust Y coordinate, keeping X and Z the same
        global_transform.origin = Vector3(
            current_pos.x, 
            collision_point.y + (model.scale.y * 0.5),
            current_pos.z
        )
