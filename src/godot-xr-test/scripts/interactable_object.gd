class_name InteractableObject extends Node3D

# Signals
signal pinch_move_started(hand_name)
signal pinch_move_ended(hand_name)
signal scaling_started
signal scaling_ended
signal rotation_started(hand_name)
signal rotation_ended(hand_name)

# Properties
@export var can_scale: bool = true
@export var can_move: bool = true
@export var can_rotate: bool = true
@export var min_scale: float = 0.1
@export var max_scale: float = 2.0
@export var rotation_speed: float = 200.0
@export var snap_to_ground: bool = false
@export var rotation_threshold: float = 0.015  # Distance in meters before rotation starts

# References
@onready var model = $Model
@onready var hand_tracking_manager: HandInteractionManager = $"/root/Main/XROrigin3D/HandInteractionManager"
@onready var interaction_zone_manager: InteractionZoneManager = $"/root/Main/XROrigin3D/InteractionZoneManager"
@onready var ground_detection: GroundDetection = $GroundDetection
@onready var interaction_area: InteractionArea = $InteractionArea/InteractionAreaInner

# State variables
var is_moving: bool = false            # Tracking if we're in movement mode
var is_scaling: bool = false           # Tracking if we're in scaling mode
var is_rotating: bool = false          # Tracking if we're in rotation mode
var movement_started: bool = false     # Tracking if we've crossed the movement threshold
var is_rotation_active: bool = false   # Tracking if we've crossed the rotation threshold
var active_hand: String = ""           # Which hand is controlling movement/rotation
var initial_pinch_position: Vector3    # Starting position of the pinching hand
var initial_object_position: Vector3   # Starting position of the object
var initial_object_rotation: float     # Starting rotation of the object
var initial_hand_x: float              # Starting X position for rotation calculation
var last_hand_x: float = 0.0           # Last frame's X position for smoother rotation
var initial_distance: float = 0.0      # Starting distance between hands for scaling
var initial_scale: float = 1.0         # Starting scale of the model
var hands_pinching: Dictionary = {"left": false, "right": false}
var hands_in_area: Dictionary = {"left": false, "right": false}  # Track which hands are in the interaction area
var cumulative_movement: float = 0.0
var last_hand_positions: Dictionary = {"left": Vector3.ZERO, "right": Vector3.ZERO}
var is_selected: bool = false

func set_selected(selected: bool):
    # Don't update if state is already correct
    if is_selected == selected:
        return
        
    is_selected = selected
    
    # Update visual feedback for selection
    #if is_selected:
        ## Show selection highlight
        #interaction_area.set_highlight(true)
    #else:
        ## Hide highlight unless there's an active interaction
        #if !is_moving:
            #interaction_area.set_highlight(false)

func _ready():
    # Connect signals from hand tracking manager
    interaction_zone_manager.pinch_started.connect(_on_pinch_started)
    interaction_zone_manager.pinch_ended.connect(_on_pinch_ended)
    
    # Store initial scale
    if model:
        initial_scale = model.scale.x
    
    print("Interactable object initialized: ", name)
    print("Can scale: ", can_scale, ", Can move: ", can_move, ", Can rotate: ", can_rotate)
    print("Rotation threshold: ", rotation_threshold)

func _process(delta):
    # Update hand positions
    _update_hand_positions()
    
    # Update hands in area
    _update_hands_in_area()
    
    # Match the scale and rotation of the interaction area with the models one
    _update_area_transform()
    
    # Check for two-hand scaling (requires selection)
    if hands_pinching["left"] and hands_pinching["right"] and can_scale and !is_scaling:
        # Only allow scaling if object is selected
        if is_selected:
            if (!is_moving and !is_rotating) or (is_rotating and !is_rotation_active) or (is_moving and !movement_started):
                # We're either not in a mode or in a pre-threshold state, so we can switch to scaling
                print("Both hands pinching - starting scaling")
                
                if is_moving:
                    _end_movement()
                if is_rotating:
                    _end_rotation()
                    
                _start_scaling()
        else:
            #print("Scaling requires object to be selected first")
            pass
    
    # Update rotation (check if we've crossed the threshold)
    if is_rotating and !is_rotation_active and active_hand != "":
        _check_rotation_threshold()
    
    # Handle the active interaction modes
    if is_scaling and can_scale:
        _update_scale()
    elif is_moving and can_move and movement_started:
        _update_position()
    elif is_rotating and can_rotate and is_rotation_active:
        _update_rotation(delta)
    
    # Apply ground snapping when not being manipulated
    if snap_to_ground and !is_moving:
        _snap_to_ground()

func _update_hand_positions():
    # Keep track of hand positions for calculations
    if hand_tracking_manager.left_controller:
        last_hand_positions["left"] = hand_tracking_manager.left_controller.global_transform.origin
    if hand_tracking_manager.right_controller:
        last_hand_positions["right"] = hand_tracking_manager.right_controller.global_transform.origin

func _update_hands_in_area():
    # Check if each hand position is inside the interaction area
    for hand_name in ["left", "right"]:
        if last_hand_positions.has(hand_name):
            var hand_position = last_hand_positions[hand_name]
            var hand_in_area = interaction_area.is_position_in_area(hand_position)
            
            # Only update and log when state changes
            if hand_in_area != hands_in_area.get(hand_name, false):
                hands_in_area[hand_name] = hand_in_area
                if hand_in_area:
                    print(hand_name, " hand entered interaction area")
                    interaction_area.set_highlight(true)
                else:
                    print(hand_name, " hand exited interaction area")
                    if active_hand == "" or active_hand != hand_name:  # Only turn off highlight if not currently interacting
                        interaction_area.set_highlight(false)

func _update_area_transform():
    interaction_area.scale_area(model.scale.x)
    interaction_area.rotate_area(model.rotation)

func _check_rotation_threshold():
    if !is_rotating or active_hand == "" or !last_hand_positions.has(active_hand):
        return
        
    var current_hand_position = last_hand_positions[active_hand]
    var movement = current_hand_position - initial_pinch_position
    var horizontal_movement = abs(current_hand_position.x - initial_pinch_position.x)
    
    # We primarily care about horizontal movement for rotation
    if horizontal_movement >= rotation_threshold:
        print("Rotation threshold crossed: ", horizontal_movement)
        is_rotation_active = true
        
        # Reset the initial positions, so the model does not jumps to the new position
        initial_pinch_position = current_hand_position
        initial_hand_x = initial_pinch_position.x
        last_hand_x = initial_hand_x
        
        emit_signal("rotation_started", active_hand)
    else:
        pass
        #print("Waiting for rotation threshold: current=", horizontal_movement, ", threshold=", rotation_threshold)

func _on_pinch_started(hand_name):
    print("Pinch started: ", hand_name)
    hands_pinching[hand_name] = true
    
    # If we're not in any interaction mode
    if !is_scaling and !is_moving and !is_rotating:
        # Single hand - check if the pinch started inside or outside the interaction area
        if hands_in_area[hand_name] and can_move:
            # Pinch inside area - start movement mode (allowed for all objects)
            print("Pinch inside interaction area, preparing movement with hand: ", hand_name)
            _start_movement(hand_name)
        elif !hands_in_area[hand_name] and can_rotate:
            # Pinch outside area - prepare rotation mode (requires selection)
            if is_selected:
                print("Pinch outside interaction area, preparing rotation with hand: ", hand_name)
                _prepare_rotation(hand_name)
            else:
                print("Rotation requires object to be selected first")
        else:
            print("Hand is pinching but not eligible for interaction")

func _on_pinch_ended(hand_name):
    print("Pinch ended: ", hand_name)
    hands_pinching[hand_name] = false
    
    # If either hand stops pinching during scaling, end scaling mode
    if is_scaling and (!hands_pinching["left"] or !hands_pinching["right"]):
        print("Ending scaling mode")
        _end_scaling()
    
    # If the active hand stops pinching during movement or rotation, end that mode
    if active_hand == hand_name:
        if is_moving:
            print("Ending movement mode")
            _end_movement()
        if is_rotating:
            print("Ending rotation mode")
            _end_rotation()

func _start_movement(hand_name):
    _reset_all_modes()
    
    is_moving = true
    active_hand = hand_name
    movement_started = true  # For simplicity, we're starting movement immediately
    
    # Store initial positions
    initial_pinch_position = last_hand_positions[hand_name]
    initial_object_position = global_transform.origin
    
    print("Movement started with hand: ", hand_name)
    emit_signal("pinch_move_started", hand_name)

func _end_movement():
    if !is_moving:
        return
        
    is_moving = false
    movement_started = false
    var previous_hand = active_hand
    active_hand = ""
    
    print("Movement ended")
    emit_signal("pinch_move_ended", previous_hand)

func _prepare_rotation(hand_name):
    _reset_all_modes()
    
    is_rotating = true
    active_hand = hand_name
    is_rotation_active = false  # We'll set this to true when the threshold is crossed
    
    # Store initial positions
    initial_pinch_position = last_hand_positions[hand_name]
    initial_hand_x = initial_pinch_position.x
    last_hand_x = initial_hand_x
    initial_object_rotation = model.rotation.y
    
    print("Rotation prepared with hand: ", hand_name)
    print("Initial hand X: ", initial_hand_x)
    print("Initial object rotation: ", initial_object_rotation)
    print("Waiting for hand to move ", rotation_threshold, "m horizontally to start rotating")

func _end_rotation():
    if !is_rotating:
        return
    
    is_rotating = false
    is_rotation_active = false
    var previous_hand = active_hand
    active_hand = ""
    
    print("Rotation ended")
    emit_signal("rotation_ended", previous_hand)

func _start_scaling():
    # Don't start scaling if we don't have positions for both hands
    if !last_hand_positions.has("left") or !last_hand_positions.has("right"):
        print("Cannot start scaling: missing hand positions")
        return
    
    _reset_all_modes()
    
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

func _reset_all_modes():
    # Reset all interaction states
    is_moving = false
    is_rotating = false
    is_scaling = false
    movement_started = false
    is_rotation_active = false
    active_hand = ""

func _update_position():
    if !is_moving or !active_hand or !last_hand_positions.has(active_hand):
        return
        
    var current_hand_position = last_hand_positions[active_hand]
    var movement_vector = current_hand_position - initial_pinch_position
    
    # Apply movement directly
    global_transform.origin = initial_object_position + movement_vector

func _update_rotation(delta):
    if !is_rotating or !is_rotation_active or !active_hand or !last_hand_positions.has(active_hand):
        return
    
    var current_hand_position = last_hand_positions[active_hand]
    
    # Get the hand movement relative to the object's position
    var object_position = global_transform.origin
    var hand_vector_prev = initial_pinch_position - object_position
    var hand_vector_current = current_hand_position - object_position
    
    # Project these vectors to the XZ plane (horizontal)
    hand_vector_prev.y = 0
    hand_vector_current.y = 0
    
    # Calculate the angle between these vectors (in radians)
    var angle = hand_vector_prev.signed_angle_to(hand_vector_current, Vector3.UP)
    
    # Use the angle for rotation, with proper delta time and sensitivity
    if model:
        var rotation_amount = angle * rotation_speed * delta
        model.rotation.y = initial_object_rotation + rotation_amount
        
        #print("Rotating: angle=", rad_to_deg(angle), " new rotation=", model.rotation.y)
     
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
