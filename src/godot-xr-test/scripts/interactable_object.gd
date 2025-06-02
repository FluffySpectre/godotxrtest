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
signal enabled_changed(enabled: bool)

# Properties
@export var can_scale: bool = true
@export var can_move: bool = true
@export var can_rotate: bool = true
@export var can_grab: bool = false
@export var min_scale: float = 0.1
@export var max_scale: float = 2.0
@export var rotation_speed: float = 200.0
@export var rotation_threshold: float = 0.03  # Distance in meters before rotation starts
@export var keep_over_ground: bool = true

# Enable/Disable Properties
@export_group("Object State")
@export var enabled: bool = true : set = set_enabled, get = get_enabled  # Whether this object can be interacted with
@export var hide_when_disabled: bool = true  # Whether to hide the object when disabled

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
@export var snap_back_speed: float = 0.1  # Speed of snap back/zone snap animation (seconds)
@export var snap_zone_max_distance: float = 0.5  # Maximum distance to consider for auto-snapping to zones
@export var home_snap_zone: SnappingZone  # Home snapping zone
@export var snap_during_flick: bool = true  # Whether to snap to zones during flick motion

# Flick Properties
@export_group("Flick Settings")
@export var enable_flick: bool = true
@export var flick_speed_threshold: float = 0.5  # Minimum hand speed to trigger flick (m/s)
@export var flick_force_multiplier: float = 1.0  # How much force to apply
@export var flick_deceleration: float = 5.0  # How quickly flick slows down (higher = faster stop)

# Rotation Flick Properties
@export var enable_rotation_flick: bool = true
@export var rotation_flick_speed_threshold: float = 1.5 # Minimum angular speed to trigger flick (rad/s)
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
var last_hand_positions: Dictionary = {"left": Vector3.ZERO, "right": Vector3.ZERO}
var is_selected: bool = false
var original_parent: Node = null       # Store the original parent for when we're detaching

# Grab state variables
var pre_grab_transform: Transform3D    # Store the transform before grabbing
var snap_back_tween: Tween             # Tween for snap back animation

# Snapping zone state variables
var current_zone: SnappingZone = null  # Currently snapped to zone
var nearby_zones: Array[SnappingZone] = []  # Zones this object is inside

# Flick state variables
var flick_velocity: Vector3 = Vector3.ZERO   # Current flick velocity
var flick_active: bool = false               # Whether object is currently in flick motion
var rotation_flick_active: bool = false      # Whether object is currently in rotation flick
var rotation_flick_velocity: float = 0.0     # Current rotation flick velocity (radians/sec)

# Velocity tracking variables
var hand_velocity: Vector3 = Vector3.ZERO    # Tracked hand velocity
var previous_hand_position: Vector3 = Vector3.ZERO  # Previous frame's hand position
var velocity_history: Array = []             # Store recent velocity samples
var rotation_velocity: float = 0.0           # Tracked rotation velocity
var previous_rotation: float = 0.0           # Previous frame's rotation
var velocity_sample_count: int = 5           # Number of samples to average for smoother velocity

# Sound tracking variables
var sound_player: AudioStreamPlayer3D
var move_distance_accumulated: float = 0.0
var rotation_accumulated: float = 0.0
var scale_change_accumulated: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var last_rotation: float = 0.0
var last_scale: float = 1.0

# Enable/Disable state variables
var _enabled: bool = true
var _enabled_before_notification: bool

# Direct scaling state
var is_direct_scaling: bool = false

func _notification(what: int) -> void:
  if what == NOTIFICATION_DISABLED:
    _enabled_before_notification = _enabled
    enabled = false
  elif what == NOTIFICATION_ENABLED:
    enabled = _enabled_before_notification

# Enable/Disable methods
func set_enabled(value: bool) -> void:
  if _enabled == value:
    return
    
  _enabled = value
  
  _apply_enabled_state()
  
  # End all interactions when disabled
  if !_enabled:
    _end_all_interactions()
  
  # Emit signal
  emit_signal("enabled_changed", _enabled)
  
  print("InteractableObject ", name, " enabled state changed to: ", _enabled)

func get_enabled() -> bool:
  return _enabled

func _apply_enabled_state() -> void:
  if _enabled:
    if hide_when_disabled:
      visible = true
  else:
    if hide_when_disabled:
      visible = false

func _end_all_interactions() -> void:
  # End any active interactions
  if is_scaling:
    _end_scaling()
  if is_moving:
    _end_movement()
  if is_rotating:
    _end_rotation()
  if is_grabbed:
    _end_grab()
  
  # Clear selection
  if is_selected:
    set_selected(false)
  
  # Cancel any ongoing animations
  _cancel_snap_back()
  
  _reset_all_modes()
  
  _update_highlight()

func set_selected(selected_: bool) -> void:
  # Don't update if state is already correct or if object is disabled
  if is_selected == selected_ || !_enabled:
    return
      
  is_selected = selected_
  
  # Emit signals
  if is_selected:
    emit_signal("selected")
  else:
    emit_signal("selection_lost")

func _ready() -> void:
  # Save original parent
  original_parent = get_parent()
  
  # Connect signals from interaction zone manager
  InteractionZoneManager.instance.pinch_started.connect(_on_pinch_started)
  InteractionZoneManager.instance.pinch_ended.connect(_on_pinch_ended)
  
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
  
  # Apply initial enabled state
  _apply_enabled_state()
  
  # Snap to nearby snapping zone if enabled
  if can_snap && home_snap_zone:
    _snap_to_home_zone()

  print("Interactable object initialized: ", name)
  print("Can scale: ", can_scale, ", Can move: ", can_move, ", Can rotate: ", can_rotate, ", Can grab: ", can_grab)

func _snap_to_home_zone() -> void:
  var zone: SnappingZone = home_snap_zone
  
  print("Snapping to starting zone: ", zone.name)
  
  # Set position and rotation immediately (no animation)
  global_position = zone.get_snap_position()
  global_rotation = zone.get_snap_rotation()
  
  # Apply snap scale
  if zone.snap_scale != Vector3.ONE:
    scale = zone.snap_scale
  
  # Update our state
  if zone.snap_object(self):
    current_zone = zone
    is_snapped_to_zone = true
    
    # Reparent to the zone
    reparent.call_deferred(zone)
    
    emit_signal("snapped_to_zone", zone)
  else:
    push_warning("Failed to snap to starting zone: " + zone.name)

func _process(delta: float) -> void:
  # Don't process interactions if disabled
  if !_enabled:
    return
  
  # Update hand positions
  _update_hand_positions()
  
  # Update hands in area
  _update_hands_in_area()
  
  # Match the scale and rotation of the interaction area with the models one
  _update_area_transform()
  
  # Update velocity tracking for active interaction
  if is_grabbed:
    _update_velocity()
  elif is_moving:
    _update_velocity()
  elif is_rotating && is_rotation_active:
    _update_rotation_velocity(delta)
  
  # Check for two-hand scaling
  if hands_pinching["left"] && hands_pinching["right"] && can_scale && !is_scaling:
    # Check if both hands are inside the interaction area (direct scaling)
    if hands_in_area["left"] && hands_in_area["right"]:
      # Direct scaling - both hands inside area
      print("Both hands pinching inside area - starting direct scaling")
      
      # If we're in movement mode, transition to scaling
      if is_moving:
        _end_movement()
      
      _start_scaling(true)  # Pass true for direct scaling
    elif is_selected:
      # Ranged scaling - requires selection
      if (!is_moving && !is_rotating) || (is_rotating && !is_rotation_active) || (is_moving && !movement_started):
        # We're either not in a mode or in a pre-threshold state, so we can switch to scaling
        print("Both hands pinching - starting ranged scaling")
        
        if is_moving:
          _end_movement()
        if is_rotating:
          _end_rotation()
            
        _start_scaling(false)  # Pass false for ranged scaling
    else:
      #print("Ranged scaling requires object to be selected first")
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

func _physics_process(delta: float) -> void:
  # Don't process physics if disabled
  if !_enabled:
    return
    
  # Handle flick physics if active
  if flick_active && enable_flick:
    _update_flick_movement(delta)
    
  # Handle rotation flick physics if active
  if rotation_flick_active && enable_rotation_flick:
    _update_rotation_flick(delta)

func _update_hand_positions() -> void:
  # Keep track of hand positions for calculations
  if HandInteractionManager.instance.left_controller_pointer:
    last_hand_positions["left"] = HandInteractionManager.instance.left_controller_pointer.global_transform.origin
  if HandInteractionManager.instance.right_controller_pointer:
    last_hand_positions["right"] = HandInteractionManager.instance.right_controller_pointer.global_transform.origin

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
        else:
          print(hand_name, " hand exited interaction area")
        
        _update_highlight()

func _update_velocity() -> void:
  # Track hand velocity for movement and grab modes
  if !active_hand || !last_hand_positions.has(active_hand):
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

func _update_rotation_velocity(delta: float) -> void:
  # Track rotation velocity for rotation flick
  if !model:
    return
    
  var current_rotation = model.rotation.y
  var frame_rotation_velocity = (current_rotation - previous_rotation) / delta
  
  # Add to velocity history for smoothing
  velocity_history.push_back(frame_rotation_velocity)
  if velocity_history.size() > velocity_sample_count:
    velocity_history.pop_front()
    
  # Calculate average rotation velocity
  rotation_velocity = 0.0
  for vel in velocity_history:
    rotation_velocity += vel
  rotation_velocity /= velocity_history.size()
  
  # Store for next frame
  previous_rotation = current_rotation

func _update_highlight() -> void:
  # Don't highlight if disabled
  if !_enabled:
    interaction_area.set_highlight(false)
    return
  
  # Check if we should show highlight
  var should_highlight = false
  
  # Show highlight if any hand is in the area
  if hands_in_area.get("left", false) || hands_in_area.get("right", false):
    should_highlight = true
  
  # Also show highlight if we're actively interacting (directly)
  if is_moving || is_grabbed:
    should_highlight = true
  
  interaction_area.set_highlight(should_highlight)

func _any_hand_in_area() -> bool:
  return hands_in_area.get("left", false) || hands_in_area.get("right", false)

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
    
    # Reset velocity tracking
    _reset_velocity_tracking()
    
    emit_signal("rotation_started", active_hand)
  else:
    pass
    #print("Waiting for rotation threshold: current=", horizontal_movement, ", threshold=", rotation_threshold)

func _on_pinch_started(hand_name: String) -> void:
  # Don't process interactions if disabled
  if !_enabled:
    return
  
  # Check if this object should respond to this pinch event
  if !_should_respond_to_pinch(hand_name):
    return
    
  print("Pinch started: ", hand_name)
  hands_pinching[hand_name] = true
  
  # Stop any ongoing snap-back or snapping animation
  if is_snapping_back:
    _cancel_snap_back()
  
  # Check if this object is already grabbed by the other hand
  if is_grabbed && active_hand != hand_name:
    if hands_in_area[hand_name]:
      _transfer_to_hand(hand_name)
    return
  
  # Check if we're in movement mode and the second hand pinches inside the area
  if is_moving && active_hand != hand_name && hands_in_area[hand_name] && can_scale:
    # Both hands are now pinching and both are inside the area - switcz to direct scaling
    print("Second hand pinched inside area while moving - switching to direct scaling")
    return
  
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
      if !InteractionZoneManager.instance.has_direct_interactions_available(hand_name):
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

func _should_respond_to_pinch(hand_name: String) -> bool:
  # Always respond if hand is in this object's interaction area (direct interaction)
  if hands_in_area.get(hand_name, false):
    return true
  
  # Check if this object is selected (required for ranged interactions)
  if !is_selected:
    return false
  
  # Allow scaling if both hands are pinching and scaling is enabled
  if can_scale && hands_pinching.get("left", false) && hands_pinching.get("right", false):
    return true
  
  # Allow rotation if this hand is outside the area, no direct interactions available, and rotation is enabled
  if can_rotate && !InteractionZoneManager.instance.has_direct_interactions_available(hand_name):
    return true
  
  # Also allow if this object is already being interacted with by this hand
  if active_hand == hand_name:
    return true
  
  # Allow if this object is already grabbed and we're checking for hand transfer
  if is_grabbed && hands_in_area.get(hand_name, false):
    return true
  
  return false

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
    
    InteractionZoneManager.instance.clear_interaction(previous_hand)
    InteractionZoneManager.instance.register_interaction(new_hand_name, self)
    
    active_hand = new_hand_name
    
    # Reset velocity tracking for the new hand
    _reset_velocity_tracking()
    
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
  
  if !InteractionZoneManager.instance.register_interaction(hand_name, self, is_direct):
    return
    
  _reset_all_modes()

  print("Starting grab with hand: ", hand_name)
  is_grabbed = true
  active_hand = hand_name
  
  # Store original transform
  pre_grab_transform = global_transform
  
  # Initialize velocity tracking
  _reset_velocity_tracking()
  
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
    
    # Check if we should apply flick from grab
    if enable_flick && hand_velocity.length() > flick_speed_threshold:
      flick_velocity = hand_velocity * flick_force_multiplier
      flick_active = true
      print("Grab flick activated with velocity: ", flick_velocity)
    else:
      flick_velocity = Vector3.ZERO
      flick_active = false
      
      # Only check for snapping if we're not flicking
      # Check if we should snap to a nearby zone
      if can_snap && snap_to_closest_zone && nearby_zones.size() > 0:
        var closest_zone = _find_closest_zone()
        if closest_zone && closest_zone.global_position.distance_to(global_position) <= snap_zone_max_distance:
          _snap_to_zone(closest_zone)
        elif snap_back_when_released:
          _snap_to_zone(home_snap_zone)
      elif snap_back_when_released:
        _snap_to_zone(home_snap_zone)
    
  # Play release sound
  if sound_player && release_sound:
    sound_player.stream = release_sound
    sound_player.play()
  
  # Reset grab state
  var previous_hand = active_hand
  is_grabbed = false
  active_hand = ""
  
  # Reset velocity tracking
  _reset_velocity_tracking()
  
  # Clear the interaction registration
  InteractionZoneManager.instance.clear_interaction(previous_hand)
  
  _update_highlight()
  
  # Emit released signal
  emit_signal("released", previous_hand)

func _cancel_snap_back() -> void:
  if snap_back_tween && snap_back_tween.is_valid():
    snap_back_tween.kill()
    snap_back_tween = null
  is_snapping_back = false

func _start_movement(hand_name: String, is_direct: bool = false) -> void:
  _reset_all_modes()
  
  if !InteractionZoneManager.instance.register_interaction(hand_name, self, is_direct):
    return
    
  is_moving = true
  active_hand = hand_name
  movement_started = true
  
  # Store initial positions
  initial_pinch_position = last_hand_positions[hand_name]
  initial_object_position = global_transform.origin
  
  # Reset velocity tracking
  _reset_velocity_tracking()
  
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
  InteractionZoneManager.instance.clear_interaction(previous_hand)
  
  # Check if we should apply flick
  if enable_flick && hand_velocity.length() > flick_speed_threshold:
    flick_velocity = hand_velocity * flick_force_multiplier
    flick_active = true
    print("Flick activated with velocity: ", flick_velocity)
  else:
    flick_velocity = Vector3.ZERO
    flick_active = false
  
  # Reset velocity tracking
  _reset_velocity_tracking()
  
  _update_highlight()
  
  print("Movement ended")
  emit_signal("pinch_move_ended", previous_hand)

func _prepare_rotation(hand_name: String, is_direct: bool = false) -> void:
  if !InteractionZoneManager.instance.register_interaction(hand_name, self, is_direct):
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
  
  # Reset velocity tracking
  _reset_velocity_tracking()
  
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
  InteractionZoneManager.instance.clear_interaction(previous_hand)
  
  # Check if we should apply rotation flick
  if enable_rotation_flick && abs(rotation_velocity) > rotation_flick_speed_threshold:
    rotation_flick_velocity = rotation_velocity * rotation_flick_force_multiplier
    rotation_flick_velocity = clampf(rotation_flick_velocity, -10.0, 10.0) # Limit velocity
    rotation_flick_active = true
    print("Rotation flick activated with velocity: ", rotation_flick_velocity)
  else:
    rotation_flick_velocity = 0.0
    rotation_flick_active = false
  
  # Reset velocity tracking
  _reset_velocity_tracking()
  
  _update_highlight()
  
  print("Rotation ended")
  emit_signal("rotation_ended", previous_hand)

func _start_scaling(is_direct: bool = false) -> void:
  # Don't start scaling if we don't have positions for both hands
  if !last_hand_positions.has("left") || !last_hand_positions.has("right"):
    print("Cannot start scaling: missing hand positions")
    return
  
  # For direct scaling, both hands should already be registered as direct interactions
  # For ranged scaling, check if any direct interactions are active
  if !is_direct:
    if InteractionZoneManager.instance.has_direct_interaction_active("left") || InteractionZoneManager.instance.has_direct_interaction_active("right"):
      print("Cannot start ranged scaling: direct interaction in progress")
      return
  
  # Try to register this interaction for both hands
  if !is_direct:
    # Ranged scaling
    if !InteractionZoneManager.instance.register_interaction("left", self, false) || !InteractionZoneManager.instance.register_interaction("right", self, false):
      return
  else:
    # Direct scaling - both hands should already be registered from movement mode
    # Register the second hand if needed
    var other_hand = "right" if active_hand == "left" else "left"
    if !InteractionZoneManager.instance.register_interaction(other_hand, self, true):
      return
    
  _reset_all_modes()
  
  is_scaling = true
  is_direct_scaling = is_direct
  
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
  
  print("Scaling started (", "direct" if is_direct else "ranged", ") with initial distance: ", initial_distance)
  emit_signal("scaling_started")

func _end_scaling() -> void:
  if !is_scaling:
    return
      
  is_scaling = false
  var was_direct = is_direct_scaling
  is_direct_scaling = false
  
  # Clear both hand registrations since scaling uses both hands
  InteractionZoneManager.instance.clear_interaction("left")
  InteractionZoneManager.instance.clear_interaction("right")
  
  _update_highlight()
  
  print("Scaling ended (was ", "direct" if was_direct else "ranged", ")")
  emit_signal("scaling_ended")

func _reset_velocity_tracking() -> void:
  # Reset unified velocity tracking variables
  hand_velocity = Vector3.ZERO
  previous_hand_position = Vector3.ZERO
  velocity_history.clear()
  rotation_velocity = 0.0
  previous_rotation = 0.0

func _reset_all_modes() -> void:
  # Reset all interaction states
  is_moving = false
  is_rotating = false
  is_scaling = false
  is_direct_scaling = false
  movement_started = false
  is_rotation_active = false
  active_hand = ""
  flick_active = false
  flick_velocity = Vector3.ZERO
  rotation_flick_active = false
  rotation_flick_velocity = 0.0
  
  # Cancel any snap back animation
  _cancel_snap_back()
  
  # Reset velocity tracking
  _reset_velocity_tracking()
  
  # Reset sound tracking variables
  move_distance_accumulated = 0.0
  rotation_accumulated = 0.0
  scale_change_accumulated = 0.0

func _update_position() -> void:
  if !is_moving || !active_hand || !last_hand_positions.has(active_hand):
    return
      
  var current_hand_position = last_hand_positions[active_hand]
  var movement_vector = current_hand_position - initial_pinch_position
  
  # Apply movement directly
  var new_position = initial_object_position + movement_vector
  
  # Constrain to ground level if keep over ground is enabled
  if keep_over_ground && ground_detection && ground_detection.ground_detected:
    var ground_position = ground_detection.ground_position
    var ground_y = ground_position.y
    
    if new_position.y < ground_y:
      new_position.y = ground_y
  
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
  var new_position = global_transform.origin + flick_velocity * delta
  
  # Constrain to ground level if keep over ground is enabled
  if keep_over_ground && ground_detection && ground_detection.ground_detected:
    var ground_position = ground_detection.ground_position
    var ground_y = ground_position.y
    
    if new_position.y < ground_y:
      new_position.y = ground_y
      if flick_velocity.y < 0:
        flick_velocity.y = 0
  
  global_transform.origin = new_position
  
  # Check for zone snapping during flick motion
  if snap_during_flick && can_snap && nearby_zones.size() > 0:
    var closest_zone = _find_closest_zone()
    if closest_zone && closest_zone.global_position.distance_to(global_position) <= snap_zone_max_distance:
      print("Snapping to zone during flick motion: ", closest_zone.name)
      # Stop flick and snap to zone
      flick_active = false
      flick_velocity = Vector3.ZERO
      _snap_to_zone(closest_zone)
      return
  
  # Apply deceleration
  var deceleration = flick_velocity.normalized() * flick_deceleration * delta
  
  # Ensure we don't overshoot zero
  if deceleration.length() > flick_velocity.length():
    flick_velocity = Vector3.ZERO
    flick_active = false
    
    # Check for snapping after flick stops (if not already snapped during motion)
    if can_snap && snap_to_closest_zone && nearby_zones.size() > 0:
      var closest_zone = _find_closest_zone()
      if closest_zone && closest_zone.global_position.distance_to(global_position) <= snap_zone_max_distance:
        _snap_to_zone(closest_zone)
      elif snap_back_when_released:
        _snap_to_zone(home_snap_zone)
    elif snap_back_when_released:
      _snap_to_zone(home_snap_zone)
  else:
    flick_velocity -= deceleration

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
  is_snapping_back = true
  
  # Play snap sound
  if sound_player && snap_to_zone_sound:
    sound_player.stream = snap_to_zone_sound
    sound_player.play()
  
  if !zone.maintain_global_transform:
    # Get target position and rotation from the zone
    var target_position = zone.get_snap_position()
    var target_rotation = zone.get_snap_rotation()
    
    var initial_transform = global_transform
    var target_transform = Transform3D(Basis.from_euler(target_rotation), target_position)
    
    # Apply target scale to the transform
    target_transform.basis = target_transform.basis.scaled(zone.snap_scale)
    
    # Animate snapping
    snap_back_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
    snap_back_tween.tween_method(
      func(progress: float): global_transform = initial_transform.interpolate_with(target_transform, progress),
      0.0, 1.0, snap_back_speed
    )
    snap_back_tween.finished.connect(func(): _on_snap_to_zone_complete(zone))
  else:
    _on_snap_to_zone_complete(zone)

func _on_snap_to_zone_complete(zone: SnappingZone) -> void:
  is_snapping_back = false
  snap_back_tween = null
  
  # Tell the zone this object has snapped to it
  if zone && zone.snap_object(self):
    current_zone = zone
    is_snapped_to_zone = true
    
    reparent(current_zone)
    
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
    
    # TODO: Fix me
    # The following reparenting is needed for cases where an unsnap is 
    # initiated without prior grabbing
    #reparent(original_parent)
    
    # Reset state
    is_snapped_to_zone = false
    current_zone = null
    
    # Animate back to the original scale
    var target_scale = 1.0
    snap_back_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
    snap_back_tween.tween_property(self, "scale", Vector3(target_scale, target_scale, target_scale), snap_back_speed)
    
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
