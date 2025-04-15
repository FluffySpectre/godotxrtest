class_name InteractionZoneManager extends Node3D

# Re-export the signals from HandInteractionManager
signal pinch_started(hand_name)
signal pinch_ended(hand_name)
signal grab_started(hand_name)
signal grab_ended(hand_name)
signal hand_pose_started(hand_name)
signal hand_pose_ended(hand_name)

# The XR camera (head) this zone is attached to
@export var xr_camera: XRCamera3D

# Reference to the hand interaction manager
@export var hand_interaction_manager: HandInteractionManager

# Cylinder parameters
@export var cylinder_radius: float = 0.4  # Constant radius of the cylinder
@export var cylinder_length: float = 1.5  # How far the cylinder extends
@export var cylinder_min_distance: float = 0.15  # Minimum distance from camera

# Whether to visualize the zone during runtime
@export var visualize_zone: bool = false
@export var zone_material: Material

# Visual debugging
@export var debug_mode: bool = false
@export var show_hand_markers: bool = false

var _is_ready: bool = false
var _cylinder_mesh: MeshInstance3D
var _debug_hand_markers: Dictionary = {}

# Variables to track which hands are inside the interaction zone
var hands_in_zone: Dictionary = {"left": false, "right": false}

func _ready() -> void:
  # Setup visualization
  if visualize_zone:
    _setup_cylinder_visualization()
  
  # Setup debug if enabled
  if debug_mode and show_hand_markers:
    _setup_debug_markers()
  
  # Connect to hand interaction manager
  if hand_interaction_manager:
    _connect_to_hand_manager()
  else:
    push_error("InteractionZoneManager: No HandInteractionManager assigned!")
  
  _is_ready = true
  print("Interaction Zone Manager initialized")

func _process(_delta) -> void:
  if _is_ready and xr_camera:
    # Update visualization position (cylinder follows camera)
    if visualize_zone and _cylinder_mesh:
      _update_cylinder_position()
    
    # Update hand positions and check if in zone
    _update_hands_in_zone()
    
    # Update debug markers
    if debug_mode and show_hand_markers:
      _update_debug_markers()

func _setup_cylinder_visualization() -> void:
  # Create a cylinder mesh to visualize the interaction zone
  _cylinder_mesh = MeshInstance3D.new()
  _cylinder_mesh.name = "CylinderVisualization"
  add_child(_cylinder_mesh)
  
  # Create cylinder mesh
  var cylinder = CylinderMesh.new()
  cylinder.top_radius = cylinder_radius
  cylinder.bottom_radius = cylinder_radius
  cylinder.height = cylinder_length
  _cylinder_mesh.mesh = cylinder
  
  # Set material
  if zone_material:
    _cylinder_mesh.material_override = zone_material
  else:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.0, 1.0, 1.0, 0.3)
    mat.flags_transparent = true
    mat.flags_unshaded = true
    _cylinder_mesh.material_override = mat
  
  # Position initially
  _update_cylinder_position()

func _update_cylinder_position() -> void:
  if not xr_camera or not _cylinder_mesh:
    return
      
  # Get camera position and forward direction
  var cam_pos = xr_camera.global_transform.origin
  var cam_forward = -xr_camera.global_transform.basis.z.normalized()
  var cam_up = xr_camera.global_transform.basis.y.normalized()
  
  # Calculate the cylinder center position (in front of camera)
  var cylinder_pos = cam_pos + (cam_forward * (cylinder_min_distance + cylinder_length/2))
  
  # Create a new transform that orients the cylinder along the camera's forward direction
  var cylinder_transform = Transform3D()
  
  # The cylinder mesh is aligned with the y-axis by default, so we need to orient it
  # along the camera's forward direction (which is the negative z-axis)
  
  # Create a basis where:
  # - The y-axis aligns with the camera's forward (-z) direction
  # - The x-axis is perpendicular to both y and global up
  # - The z-axis completes the right-handed basis
  
  # Start with the camera's forward direction as our new y-axis
  var new_y = cam_forward
  
  # Create a new x-axis perpendicular to our new y and the global up
  var new_x = cam_up.cross(new_y).normalized()
  
  # Complete the right-handed basis with a new z-axis
  var new_z = new_y.cross(new_x).normalized()
  
  # Create the properly oriented basis
  cylinder_transform.basis = Basis(new_x, new_y, new_z)
  
  # Set the position
  cylinder_transform.origin = cylinder_pos
  
  # Apply the transform to the cylinder
  _cylinder_mesh.global_transform = cylinder_transform

func _update_hands_in_zone() -> void:
  if not hand_interaction_manager:
    return
  
  # Check each hand position using our cylinder-based detection
  _check_hand_in_zone("left")
  _check_hand_in_zone("right")

func _check_hand_in_zone(hand_name: String) -> void:
  if not xr_camera or not hand_interaction_manager:
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
  
  # Debug info if enabled
  if debug_mode:
    if is_in_zone != hands_in_zone.get(hand_name, false):
      print(hand_name + " hand: " +
            "dist=" + str(projected_distance) + ", " +
            "perp=" + str(perpendicular_distance) + ", " +
            "radius=" + str(cylinder_radius) + ", " +
            "in_zone=" + str(is_in_zone))

func _update_hand_zone_state(hand_name: String, is_in_zone: bool) -> void:
  # Only update if state changed
  if is_in_zone != hands_in_zone.get(hand_name, false):
    hands_in_zone[hand_name] = is_in_zone
    if is_in_zone:
      print(hand_name, " hand entered interaction zone")
    else:
      print(hand_name, " hand exited interaction zone")
    
    # Update marker colors if debugging
    if debug_mode and show_hand_markers and _debug_hand_markers.has(hand_name):
      var marker = _debug_hand_markers[hand_name]
      var mat = marker.material_override as StandardMaterial3D
      if mat:
        # Set color based on whether hand is in zone
        if is_in_zone:
          mat.albedo_color = Color(0, 1, 0)  # Green when in zone
        else:
          mat.albedo_color = Color(1, 0, 0) if hand_name == "left" else Color(0, 0, 1)

func _connect_to_hand_manager() -> void:
  # Connect to hand interaction manager signals
  hand_interaction_manager.pinch_started.connect(_filter_pinch_started)
  hand_interaction_manager.pinch_ended.connect(_filter_pinch_ended)
  hand_interaction_manager.grab_started.connect(_filter_grab_started)
  hand_interaction_manager.grab_ended.connect(_filter_grab_ended)
  hand_interaction_manager.hand_pose_started.connect(_filter_hand_pose_started)
  hand_interaction_manager.hand_pose_ended.connect(_filter_hand_pose_ended)

# Signal filters
func _filter_pinch_started(hand_name: String) -> void:
  if hands_in_zone.get(hand_name, false):
    emit_signal("pinch_started", hand_name)
  else:
    print("Ignoring pinch start from " + hand_name + " hand (outside interaction zone)")

func _filter_pinch_ended(hand_name: String) -> void:
  emit_signal("pinch_ended", hand_name)

func _filter_grab_started(hand_name: String) -> void:
  if hands_in_zone.get(hand_name, false):
    emit_signal("grab_started", hand_name)
  else:
    print("Ignoring grab start from " + hand_name + " hand (outside interaction zone)")

func _filter_grab_ended(hand_name: String) -> void:
  emit_signal("grab_ended", hand_name)

func _filter_hand_pose_started(hand_name: String) -> void:
  if hands_in_zone.get(hand_name, false):
    emit_signal("hand_pose_started", hand_name)
  else:
    print("Ignoring hand pose start from " + hand_name + " hand (outside interaction zone)")

func _filter_hand_pose_ended(hand_name: String) -> void:
  emit_signal("hand_pose_ended", hand_name)

# Debug visualization
func _setup_debug_markers() -> void:
  # Create visual markers for hand positions
  for hand_name in ["left", "right"]:
    var marker = MeshInstance3D.new()
    marker.name = hand_name + "_HandMarker"
    
    # Create a small sphere mesh for the marker
    var sphere_mesh = SphereMesh.new()
    sphere_mesh.radius = 0.03
    sphere_mesh.height = 0.06
    marker.mesh = sphere_mesh
    
    # Set material by hand
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1, 0, 0) if hand_name == "left" else Color(0, 0, 1)
    material.flags_unshaded = true
    marker.material_override = material
    
    add_child(marker)
    _debug_hand_markers[hand_name] = marker
    marker.visible = true

func _update_debug_markers() -> void:
  # Update marker positions to match hand positions
  for hand_name in ["left", "right"]:
    if _debug_hand_markers.has(hand_name) and hand_interaction_manager:
      var hand_position = hand_interaction_manager.get_hand_position(hand_name)
      if hand_position != Vector3.ZERO:
        _debug_hand_markers[hand_name].global_position = hand_position
        _debug_hand_markers[hand_name].visible = true
      else:
        _debug_hand_markers[hand_name].visible = false
