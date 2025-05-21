class_name InteractableObject extends Node3D

# Signals
signal pinch_move_started(hand_name: String)
signal pinch_move_ended(hand_name: String)
signal scaling_started
signal scaling_ended
signal rotation_started(hand_name: String)
signal rotation_ended(hand_name: String)
signal selected
signal selection_lost
signal grabbed(hand_name: String)
signal released(hand_name: String)
signal hand_transfer(previous_hand: String, new_hand: String)
signal snapped_to_zone(zone: SnappingZone)
signal unsnapped_from_zone()
signal entered_zone(zone: SnappingZone)
signal exited_zone(zone: SnappingZone)

# Properties
@export var can_scale: bool = true
@export var can_move: bool = true
@export var can_rotate: bool = true
@export var can_grab: bool = false
@export var min_scale: float = 0.1
@export var max_scale: float = 2.0
@export var rotation_speed: float = 200.0
@export var snap_to_ground: bool = false
@export var rotation_threshold: float = 0.02  # Distance in meters before rotation starts

# Object Properties
@export_group("Object Settings")
@export var tag: String = ""  # Tag for filtering in SnappingZones

# Grab Properties
@export_group("Grab Settings")
@export var grab_offset: Vector3 = Vector3(0, 0, 0)  # Offset from the hand attachment point
@export var maintain_global_rotation: bool = false  # Whether to maintain world rotation when grabbed

# Snapping Properties
@export_group("Snapping Settings")
@export var can_snap: bool = true  # Whether this object can snap to SnappingZones
@export var snap_back_when_released: bool = false  # Whether to return to original position when released
@export var snap_to_closest_zone: bool = true  # Whether to snap to closest zone when released
@export var snap_back_speed: float = 0.25  # Speed of snap back/zone snap animation (seconds)
@export var snap_zone_max_distance: float = 0.5  # Maximum distance to consider for auto-snapping to zones

# Flick Properties
@export_group("Flick Settings")
@export var enable_flick: bool = true
@export var flick_speed_threshold: float = 0.5  # Minimum hand speed to trigger flick (m/s)
@export var flick_force_multiplier: float = 1.0  # How much force to apply
@export var flick_deceleration: float = 5.0  # How quickly flick slows down (higher = faster stop)

# Rotation Flick Properties
@export var enable_rotation_flick: bool = true
@export var rotation_flick_speed_threshold: float = 0.3  # Minimum angular speed to trigger flick (rad/s)
@export var rotation_flick_force_multiplier: float = 1.0  # How much force to apply to rotation
@export var rotation_flick_deceleration: float = 3.0  # How quickly rotation flick slows down

# Sound Properties
@export_group("Sound Settings")
@export var move_sound: AudioStream  # Sound to play during movement
@export var rotation_sound: AudioStream  # Sound to play during rotation  
@export var scale_sound: AudioStream  # Sound to play during scaling
@export var grab_sound: AudioStream  # Sound for grabbing
@export var release_sound: AudioStream  # Sound for releasing
@export var snap_back_sound: AudioStream  # Sound for snapping back
@export var snap_to_zone_sound: AudioStream  # Sound for snapping to a zone
@export var unsnap_from_zone_sound: AudioStream  # Sound for unsnapping from a zone
@export var move_sound_interval: float = 0.1  # Distance in meters between sound clicks
@export var rotation_sound_interval: float = 0.15  # Radians between sound clicks
@export var scale_sound_interval: float = 0.1  # Scale factor change between sound clicks

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
var is_grabbed: bool = false           # Tracking if the object is currently grabbed
var is_snapping_back: bool = false     # Tracking if the object is snapping back
var is_snapped_to_zone: bool = false   # Tracking if currently snapped to a zone
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
var original_parent: Node = null       # Store the original parent for when we're detaching

# Grab state variables
var pre_grab_transform: Transform3D    # Store the transform before grabbing
var snap_back_target_transform: Transform3D  # Store the transform to snap back to
var snap_back_tween: Tween             # Tween for snap back animation

# Snapping zone state variables
var current_zone: SnappingZone = null  # Currently snapped to zone
var nearby_zones: Array[SnappingZone] = []  # Zones this object is inside

# Flick state variables
var flick_velocity: Vector3 = Vector3.ZERO   # Current flick velocity
var flick_active: bool = false               # Whether object is currently in flick motion
var hand_velocity: Vector3 = Vector3.ZERO    # Tracked hand velocity
var previous_hand_position: Vector3 = Vector3.ZERO  # Previous frame's hand position
var velocity_history: Array = []             # Store recent velocity samples
var velocity_sample_count: int = 5           # Number of samples to average for smoother velocity

# Rotation flick state variables
var rotation_flick_active: bool = false      # Whether object is currently in rotation flick
var rotation_flick_velocity: float = 0.0     # Current rotation flick velocity (radians/sec)
var rotation_velocity: float = 0.0           # Tracked rotation velocity
var previous_rotation: float = 0.0           # Previous frame's rotation
var rotation_velocity_history: Array = []    # Store recent rotation velocity samples

# Sound tracking variables
var sound_player: AudioStreamPlayer3D
var move_distance_accumulated: float = 0.0
var rotation_accumulated: float = 0.0
var scale_change_accumulated: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var last_rotation: float = 0.0
var last_scale: float = 1.0

func set_selected(selected_: bool) -> void:
  # Don't update if state is already correct
  if is_selected == selected_:
    return
      
  is_selected = selected_
  
  # Emit signals
  if is_selected:
    emit_signal("selected")
  else:
    emit_signal("selection_lost")

func _ready() -> void:
  # Connect signals from interaction zone manager
  interaction_zone_manager.pinch_started.connect(_on_pinch_started)
  interaction_zone_manager.pinch_ended.connect(_on_pinch_ended)
  
  # Store initial scale
  if model:
    initial_scale = model.scale.x
    last_scale = initial_scale
  
  # Initialize position and rotation tracking for sound effects
  last_position = global_transform.origin
  if model:
    last_rotation = model.rotation.y
    previous_rotation = last_rotation
  
  # Setup sound
  if has_node("SoundPlayer"):
    sound_player = get_node("SoundPlayer")
  
  # Set up the metadata to link back to this interactable
  interaction_area.set_meta("parent_interactable", self)
  
  # Add to interactable group to make it easier to find all interactables
  add_to_group("interactable")
  
  print("Interactable object initialized: ", name)
  print("Can scale: ", can_scale, ", Can move: ", can_move, ", Can rotate: ", can_rotate, ", Can grab: ", can_grab)

func _process(delta: float) -> void:
  # Update hand positions
  _update_hand_positions()
  
  # Update hands in area
  _update_hands_in_area()
  
  # Match the scale and rotation of the interaction area with the models one
  _update_area_transform()
  
  # Check for two-hand scaling (requires selection)
  if hands_pinching["left"] && hands_pinching["right"] && can_scale && !is_scaling:
    # Only allow scaling if object is selected
    if is_selected:
      if (!is_moving && !is_rotating) || (is_rotating && !is_rotation_active) || (is_moving && !movement_started):
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
  if is_rotating && !is_rotation_active && active_hand != "":
    _check_rotation_threshold()
  
  # Handle the active interaction modes
  if is_scaling && can_scale:
    _update_scale()
  elif is_moving && can_move && movement_started:
    _update_position()
  elif is_rotating && can_rotate && is_rotation_active:
    _update_rotation(delta)
  
  # Apply ground snapping when not being manipulated
  if snap_to_ground && !is_moving && !flick_active && !is_grabbed && !is_snapping_back && !is_snapped_to_zone:
    _snap_to_ground()

func _physics_process(delta: float) -> void:
  # Handle flick physics if active
  if flick_active && enable_flick:
    _update_flick_movement(delta)
    
  # Handle rotation flick physics if active
  if rotation_flick_active && enable_rotation_flick:
    _update_rotation_flick(delta)

func _update_hand_positions() -> void:
  # Keep track of hand positions for calculations
  if hand_tracking_manager.left_controller:
    last_hand_positions["left"] = hand_tracking_manager.left_controller.global_transform.origin
  if hand_tracking_manager.right_controller:
    last_hand_positions["right"] = hand_tracking_manager.right_controller.global_transform.origin

func _update_hands_in_area() -> void:
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
          if active_hand == "" || active_hand != hand_name:  # Only turn off highlight if not currently interacting
            interaction_area.set_highlight(false)

func _update_area_transform() -> void:
  if !model:
    return
  interaction_area.scale_area(model.scale.x)
  interaction_area.rotate_area(model.rotation)

func _check_rotation_threshold() -> void:
  if !is_rotating || active_hand == "" || !last_hand_positions.has(active_hand):
    return
      
  var current_hand_position = last_hand_positions[active_hand]
  var horizontal_movement = abs(current_hand_position.x - initial_pinch_position.x)
  
  # We primarily care about horizontal movement for rotation
  if horizontal_movement >= rotation_threshold:
    print("Rotation threshold crossed: ", horizontal_movement)
    is_rotation_active = true
    
    # Reset the initial positions, so the model does not jumps to the new position
    initial_pinch_position = current_hand_position
    initial_hand_x = initial_pinch_position.x
    last_hand_x = initial_hand_x
    
    # Reset rotation velocity tracking
    rotation_velocity = 0.0
    rotation_velocity_history.clear()
    
    emit_signal("rotation_started", active_hand)
  else:
    pass
    #print("Waiting for rotation threshold: current=", horizontal_movement, ", threshold=", rotation_threshold)

func _on_pinch_started(hand_name: String) -> void:
  print("Pinch started: ", hand_name)
  hands_pinching[hand_name] = true
  
  # Stop any ongoing snap-back or snapping animation
  if is_snapping_back:
    _cancel_snap_back()
  
  # Check if this object is already grabbed by the other hand
  if is_grabbed && active_hand != hand_name:
    # This is a hand transfer situation - transfer from current hand to new hand
    _transfer_to_hand(hand_name)
    return
  
  # If we're not in any interaction mode
  if !is_scaling && !is_moving && !is_rotating && !is_grabbed:
    # If this object is snapped to a zone, unsnap it when grabbed
    if is_snapped_to_zone && current_zone:
      unsnap_from_zone()
      
    # Single hand - check if the pinch started inside or outside the interaction area
    if hands_in_area[hand_name] && can_move:
      # Pinch inside area - start movement mode (allowed for all objects)
      print("Pinch inside interaction area, preparing movement with hand: ", hand_name)
      _start_movement(hand_name, true)  # Pass true to indicate direct interaction
    elif hands_in_area[hand_name] && can_grab:
      _start_grab(hand_name, true)  # Pass true to indicate direct interaction
    elif !hands_in_area[hand_name] && can_rotate:
      # Only start rotation if no direct interactions are available for this hand
      if !interaction_zone_manager.has_direct_interactions_available(hand_name):
        # Pinch outside area - prepare rotation mode (requires selection)
        if is_selected:
          print("Pinch outside interaction area, preparing rotation with hand: ", hand_name)
          _prepare_rotation(hand_name, false)  # Pass false to indicate ranged interaction
        else:
          print("Rotation requires object to be selected first")
      else:
        print("Ignoring rotation as direct interactions are available")
    else:
      print("Hand is pinching but not eligible for interaction")

func _on_pinch_ended(hand_name: String) -> void:
  print("Pinch ended: ", hand_name)
  hands_pinching[hand_name] = false
  
  # If either hand stops pinching during scaling, end scaling mode
  if is_scaling && (!hands_pinching["left"] || !hands_pinching["right"]):
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
    if is_grabbed:
      print("Ending grabbing mode")
      _end_grab()

func _transfer_to_hand(new_hand_name: String) -> void:
  if !is_grabbed || new_hand_name == active_hand:
    return
  
  print("Transferring object from " + active_hand + " hand to " + new_hand_name + " hand")
  
  var previous_hand = active_hand
  
  # Get the new hand attachment point
  var attachment_point = XRRig.AttachmentPoint.LEFT_HAND if new_hand_name == "left" else XRRig.AttachmentPoint.RIGHT_HAND
  var attachment_node = XRRig.instance.get_attachment_point_node(attachment_point)
  
  if attachment_node:
    # Save current global transform
    var current_global_transform = global_transform
    
    interaction_zone_manager.clear_interaction(previous_hand)
    interaction_zone_manager.register_interaction(new_hand_name, self)
    
    active_hand = new_hand_name
    
    reparent(attachment_node)
    
    # Apply offset if needed
    if grab_offset != Vector3.ZERO:
      position = grab_offset
    
    if maintain_global_rotation:
      global_rotation = current_global_transform.basis.get_euler()
    
    emit_signal("hand_transfer", previous_hand, new_hand_name)
  else:
    print("ERROR: Could not find attachment point for hand: ", new_hand_name)

func _start_grab(hand_name: String, is_direct: bool = false) -> void:
  if is_grabbed:
    return
  
  if !interaction_zone_manager.register_interaction(hand_name, self, is_direct):
    return
    
  _reset_all_modes()

  print("Starting grab with hand: ", hand_name)
  is_grabbed = true
  active_hand = hand_name
  
  # Store original parent and transform
  original_parent = get_parent()
  pre_grab_transform = global_transform
  
  # Store the snap-back target transform
  snap_back_target_transform = pre_grab_transform
  
  # Get the hand attachment point
  var attachment_point = XRRig.AttachmentPoint.LEFT_HAND if hand_name == "left" else XRRig.AttachmentPoint.RIGHT_HAND
  var attachment_node = XRRig.instance.get_attachment_point_node(attachment_point)
  
  if attachment_node:
    # Reparent to the hand
    reparent(attachment_node)
    
    # Apply offset if needed
    if grab_offset != Vector3.ZERO:
      position = grab_offset
    
    # Maintain global rotation if specified
    if maintain_global_rotation:
      global_rotation = pre_grab_transform.basis.get_euler()
    
    # Play grab sound
    if sound_player && grab_sound:
      sound_player.stream = grab_sound
      sound_player.play()
    
    # Emit grabbed signal
    emit_signal("grabbed", hand_name)
  else:
    print("ERROR: Could not find attachment point for hand: ", hand_name)
    is_grabbed = false
    active_hand = ""

func _end_grab() -> void:
  if !is_grabbed:
    return
    
  print("Ending grab")
  
  # Return to original parent
  if original_parent:
    # Save current global transform
    var current_global_transform = global_transform
    
    # Reparent back to original parent
    reparent(original_parent)
    
    # Restore global transform to maintain position and rotation in world space
    global_transform = current_global_transform
    
    # Check if we should snap to a nearby zone
    if can_snap && snap_to_closest_zone && nearby_zones.size() > 0:
      var closest_zone = _find_closest_zone()
      if closest_zone && closest_zone.global_position.distance_to(global_position) <= snap_zone_max_distance:
        _snap_to_zone(closest_zone)
      elif snap_back_when_released:
        _start_snap_back_animation()
    elif snap_back_when_released:
      # If no zones to snap to, snap back to original position
      _start_snap_back_animation()
    
  # Play release sound
  if sound_player && release_sound:
    sound_player.stream = release_sound
    sound_player.play()
  
  # Reset grab state
  var previous_hand = active_hand
  is_grabbed = false
  active_hand = ""
  
  # Clear the interaction registration
  interaction_zone_manager.clear_interaction(previous_hand)
  
  # Emit released signal
  emit_signal("released", previous_hand)

func _start_snap_back_animation() -> void:
  print("Starting snap back animation")
  is_snapping_back = true
  
  # Cancel any existing tween
  _cancel_snap_back()
  
  # Create a new tween for the snap back animation
  snap_back_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
  
  # Animate position and rotation back to original transform
  snap_back_tween.tween_property(self, "global_position", snap_back_target_transform.origin, snap_back_speed)
  
  # Extract the rotation from the transform's basis
  var target_rotation = snap_back_target_transform.basis.get_euler()
  snap_back_tween.parallel().tween_property(self, "global_rotation", target_rotation, snap_back_speed)
  
  # Connect to the tween's finished signal
  snap_back_tween.finished.connect(_on_snap_back_complete)
  
  # Play snap back sound if available
  if sound_player && snap_back_sound:
    sound_player.stream = snap_back_sound
    sound_player.play()

func _cancel_snap_back() -> void:
  if snap_back_tween && snap_back_tween.is_valid():
    snap_back_tween.kill()
    snap_back_tween = null
  is_snapping_back = false

func _on_snap_back_complete() -> void:
  print("Snap back animation complete")
  is_snapping_back = false
  snap_back_tween = null

func _start_movement(hand_name: String, is_direct: bool = false) -> void:
  _reset_all_modes()
  
  if !interaction_zone_manager.register_interaction(hand_name, self, is_direct):
    return
    
  is_moving = true
  active_hand = hand_name
  movement_started = true  # For simplicity, we're starting movement immediately
  
  # Store initial positions
  initial_pinch_position = last_hand_positions[hand_name]
  initial_object_position = global_transform.origin
  previous_hand_position = Vector3.ZERO
  
  # Reset tracking
  velocity_history.clear()
  hand_velocity = Vector3.ZERO
  
  # Reset sound tracking
  move_distance_accumulated = 0.0
  last_position = global_transform.origin
  
  print("Movement started with hand: ", hand_name)
  emit_signal("pinch_move_started", hand_name)

func _end_movement() -> void:
  if !is_moving:
    return
      
  is_moving = false
  movement_started = false
  var previous_hand = active_hand
  active_hand = ""
  
  # Clear the interaction registration
  interaction_zone_manager.clear_interaction(previous_hand)
  
  # Check if we should apply flick
  if enable_flick && hand_velocity.length() > flick_speed_threshold:
    flick_velocity = hand_velocity * flick_force_multiplier
    flick_active = true
    print("Flick activated with velocity: ", flick_velocity)
  else:
    flick_velocity = Vector3.ZERO
    flick_active = false
  
  # Reset velocity tracking
  hand_velocity = Vector3.ZERO
  previous_hand_position = Vector3.ZERO
  velocity_history.clear()
  
  print("Movement ended")
  emit_signal("pinch_move_ended", previous_hand)

func _prepare_rotation(hand_name: String, is_direct: bool = false) -> void:
  if !interaction_zone_manager.register_interaction(hand_name, self, is_direct):
    return
    
  _reset_all_modes()
  
  is_rotating = true
  active_hand = hand_name
  is_rotation_active = false  # We'll set this to true when the threshold is crossed
  
  # Store initial positions
  initial_pinch_position = last_hand_positions[hand_name]
  initial_hand_x = initial_pinch_position.x
  last_hand_x = initial_hand_x
  initial_object_rotation = model.rotation.y
  
  # Reset rotation velocity tracking
  rotation_velocity = 0.0
  rotation_velocity_history.clear()
  
  # Reset sound tracking
  rotation_accumulated = 0.0
  last_rotation = model.rotation.y
  previous_rotation = last_rotation
  
  print("Rotation prepared with hand: ", hand_name)
  print("Initial hand X: ", initial_hand_x)
  print("Initial object rotation: ", initial_object_rotation)
  print("Waiting for hand to move ", rotation_threshold, "m horizontally to start rotating")

func _end_rotation() -> void:
  if !is_rotating:
    return
  
  is_rotating = false
  is_rotation_active = false
  var previous_hand = active_hand
  active_hand = ""
  
  # Clear the interaction registration
  interaction_zone_manager.clear_interaction(previous_hand)
  
  # Check if we should apply rotation flick
  if enable_rotation_flick && abs(rotation_velocity) > rotation_flick_speed_threshold:
    rotation_flick_velocity = rotation_velocity * rotation_flick_force_multiplier
    rotation_flick_active = true
    print("Rotation flick activated with velocity: ", rotation_flick_velocity)
  else:
    rotation_flick_velocity = 0.0
    rotation_flick_active = false
  
  # Reset rotation velocity tracking
  rotation_velocity = 0.0
  rotation_velocity_history.clear()
  
  print("Rotation ended")
  emit_signal("rotation_ended", previous_hand)

func _start_scaling() -> void:
  # Don't start scaling if we don't have positions for both hands
  if !last_hand_positions.has("left") || !last_hand_positions.has("right"):
    print("Cannot start scaling: missing hand positions")
    return
  
  # Check if any direct interactions are active
  if interaction_zone_manager.has_direct_interaction_active("left") || interaction_zone_manager.has_direct_interaction_active("right"):
    print("Cannot start scaling: direct interaction in progress")
    return
  
  # Try to register this interaction for both hands
  if !interaction_zone_manager.register_interaction("left", self, false) || !interaction_zone_manager.register_interaction("right", self, false):
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
  
  # Reset sound tracking
  scale_change_accumulated = 0.0
  last_scale = initial_scale
  
  print("Scaling started with initial distance: ", initial_distance)
  emit_signal("scaling_started")

func _end_scaling() -> void:
  if !is_scaling:
    return
      
  is_scaling = false
  
  # Clear both hand registrations since scaling uses both hands
  interaction_zone_manager.clear_interaction("left")
  interaction_zone_manager.clear_interaction("right")
  
  print("Scaling ended")
  emit_signal("scaling_ended")

func _reset_all_modes() -> void:
  # Reset all interaction states
  is_moving = false
  is_rotating = false
  is_scaling = false
  movement_started = false
  is_rotation_active = false
  active_hand = ""
  flick_active = false
  flick_velocity = Vector3.ZERO
  rotation_flick_active = false
  rotation_flick_velocity = 0.0
  
  # Cancel any snap back animation
  _cancel_snap_back()
  
  # Reset sound tracking variables
  move_distance_accumulated = 0.0
  rotation_accumulated = 0.0
  scale_change_accumulated = 0.0

func _update_position() -> void:
  if !is_moving || !active_hand || !last_hand_positions.has(active_hand):
    return
      
  var current_hand_position = last_hand_positions[active_hand]
  
  # Calculate hand velocity
  if previous_hand_position != Vector3.ZERO:
    var frame_velocity = (current_hand_position - previous_hand_position) / get_physics_process_delta_time()
    
    # Add to velocity history for smoothing
    velocity_history.push_back(frame_velocity)
    if velocity_history.size() > velocity_sample_count:
      velocity_history.pop_front()
      
    # Calculate average velocity
    hand_velocity = Vector3.ZERO
    for vel in velocity_history:
      hand_velocity += vel
    hand_velocity /= velocity_history.size()
  
  # Store for next frame
  previous_hand_position = current_hand_position
  
  var movement_vector = current_hand_position - initial_pinch_position
  
  # Apply movement directly
  var new_position = initial_object_position + movement_vector
  global_transform.origin = new_position
  
  # Check for sound trigger
  if last_position != Vector3.ZERO:
    var movement_distance = last_position.distance_to(new_position)
    move_distance_accumulated += movement_distance
    
    # Play sound at regular intervals
    if move_distance_accumulated >= move_sound_interval:
      _play_move_sound()
      # Keep remainder for smoother timing
      move_distance_accumulated = fmod(move_distance_accumulated, move_sound_interval)
  
  last_position = new_position

func _update_flick_movement(delta: float) -> void:
  # Apply current flick velocity to position
  global_transform.origin += flick_velocity * delta
  
  # Apply deceleration
  var deceleration = flick_velocity.normalized() * flick_deceleration * delta
  
  # Ensure we don't overshoot zero
  if deceleration.length() > flick_velocity.length():
    flick_velocity = Vector3.ZERO
    flick_active = false
  else:
    flick_velocity -= deceleration
  
  # Apply ground snapping if enabled
  if snap_to_ground:
    _snap_to_ground()

func _update_rotation(delta: float) -> void:
  if !is_rotating || !is_rotation_active || !active_hand || !last_hand_positions.has(active_hand):
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
    var new_rotation = initial_object_rotation + rotation_amount
    model.rotation.y = new_rotation
    
    # Calculate rotation velocity for flick
    var frame_rotation_velocity = (new_rotation - previous_rotation) / delta
    
    # Add to velocity history for smoothing
    rotation_velocity_history.push_back(frame_rotation_velocity)
    if rotation_velocity_history.size() > velocity_sample_count:
      rotation_velocity_history.pop_front()
      
    # Calculate average rotation velocity
    rotation_velocity = 0.0
    for vel in rotation_velocity_history:
      rotation_velocity += vel
    rotation_velocity /= rotation_velocity_history.size()
    
    # Store for next frame
    previous_rotation = new_rotation
    
    # Check for sound trigger
    if last_rotation != 0.0:
      var rotation_change = abs(new_rotation - last_rotation)
      rotation_accumulated += rotation_change
      
      # Play sound at regular intervals
      if rotation_accumulated >= rotation_sound_interval:
        _play_rotation_sound()
        # Keep remainder for smoother timing
        rotation_accumulated = fmod(rotation_accumulated, rotation_sound_interval)
    
    last_rotation = new_rotation

func _update_rotation_flick(delta: float) -> void:
  if !model || !rotation_flick_active:
    return
  
  # Apply current rotation flick velocity
  model.rotation.y += rotation_flick_velocity * delta
  
  # Apply deceleration
  var deceleration = sign(rotation_flick_velocity) * rotation_flick_deceleration * delta
  
  # Ensure we don't overshoot zero
  if abs(deceleration) > abs(rotation_flick_velocity):
    rotation_flick_velocity = 0.0
    rotation_flick_active = false
  else:
    rotation_flick_velocity -= deceleration
  
  # Check for sound trigger during flick rotation
  if last_rotation != 0.0:
    var rotation_change = abs(model.rotation.y - last_rotation)
    rotation_accumulated += rotation_change
    
    # Play sound at regular intervals
    if rotation_accumulated >= rotation_sound_interval:
      _play_rotation_sound()
      # Keep remainder for smoother timing
      rotation_accumulated = fmod(rotation_accumulated, rotation_sound_interval)
  
  last_rotation = model.rotation.y
     
func _update_scale() -> void:
  if !is_scaling || !model:
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
  
  # Check for sound trigger
  if last_scale != 0.0:
    var scale_change = abs(new_scale - last_scale)
    scale_change_accumulated += scale_change
    
    # Play sound at regular intervals
    if scale_change_accumulated >= scale_sound_interval:
      _play_scale_sound()
      # Keep remainder for smoother timing
      scale_change_accumulated = fmod(scale_change_accumulated, scale_sound_interval)
  
  last_scale = new_scale

func _snap_to_ground() -> void:
  if ground_detection && ground_detection.is_colliding():
    var collision_point = ground_detection.get_collision_point()
    var current_pos = global_transform.origin
    global_transform.origin = Vector3(
      current_pos.x, 
      collision_point.y + (model.scale.y * 0.5),
      current_pos.z
    )

func _find_closest_zone() -> SnappingZone:
  if nearby_zones.size() == 0:
    return null
    
  var closest_zone: SnappingZone = null
  var closest_distance: float = INF
  
  for zone in nearby_zones:
    if !zone.enabled:
      continue
      
    if zone.object_filter_tag && zone.object_filter_tag != tag:
      continue
      
    var distance = global_position.distance_to(zone.global_position)
    if distance < closest_distance:
      closest_distance = distance
      closest_zone = zone
      
  return closest_zone

func _snap_to_zone(zone: SnappingZone) -> void:
  if !zone || is_snapped_to_zone:
    return
    
  print("Snapping to zone: ", zone.name)
  
  # Set up animation
  _cancel_snap_back()  # Cancel any existing animations
  is_snapping_back = true  # Reuse the same flag
  
  # Get target position and rotation from the zone
  var target_position = zone.get_snap_position()
  var target_rotation = zone.get_snap_rotation()
  
  var initial_transform = global_transform
  var target_transform = Transform3D(Basis.from_euler(target_rotation), target_position)
  snap_back_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
  snap_back_tween.tween_method(func(progress: float): global_transform = initial_transform.interpolate_with(target_transform, progress), 0.0, 1.0, snap_back_speed)
  snap_back_tween.finished.connect(func(): _on_snap_to_zone_complete(zone))
  
  # Play snap sound
  if sound_player && snap_to_zone_sound:
    sound_player.stream = snap_to_zone_sound
    sound_player.play()

func _on_snap_to_zone_complete(zone: SnappingZone) -> void:
  is_snapping_back = false
  snap_back_tween = null
  
  # Tell the zone this object has snapped to it
  if zone && zone.snap_object(self):
    current_zone = zone
    is_snapped_to_zone = true
    
    # TODO
    #reparent(current_zone)
    
    emit_signal("snapped_to_zone", zone)

func snap_to_zone(zone: SnappingZone) -> void:
  if zone && !is_grabbed && !is_snapped_to_zone:
    current_zone = zone
    
    is_snapped_to_zone = true
    emit_signal("snapped_to_zone", zone)

func unsnap_from_zone() -> void:
  if is_snapped_to_zone && current_zone:
    # Tell the zone we're unsnapping (if it doesn't already know)
    if current_zone.snapped_object == self:
      current_zone.unsnap_object(self)
    
    # Reset state
    var previous_zone = current_zone
    current_zone = null
    is_snapped_to_zone = false
    
    # Play sound
    if sound_player && unsnap_from_zone_sound:
      sound_player.stream = unsnap_from_zone_sound
      sound_player.play()
    
    # Emit signal
    emit_signal("unsnapped_from_zone")

func entered_snapping_zone(zone: SnappingZone) -> void:
  if zone && !nearby_zones.has(zone):
    nearby_zones.append(zone)
    emit_signal("entered_zone", zone)

func exited_snapping_zone(zone: SnappingZone) -> void:
  if zone && nearby_zones.has(zone):
    nearby_zones.erase(zone)
    emit_signal("exited_zone", zone)

func _play_move_sound() -> void:
  if sound_player && move_sound:
    sound_player.stream = move_sound
    sound_player.play()

func _play_rotation_sound() -> void:
  if sound_player && rotation_sound:
    sound_player.stream = rotation_sound
    sound_player.play()

func _play_scale_sound() -> void:
  if sound_player && scale_sound:
    sound_player.stream = scale_sound
    sound_player.play()
