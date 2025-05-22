class_name FloatingViewPanel extends Node3D

# Properties
@export_group("Panel Properties")
@export var panel_width: float = 0.5  # Width in meters
@export var panel_height: float = 0.3  # Height in meters
@export var panel_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var panel_material: Material  # Optional custom material

@export_group("Position and Movement")
@export var distance_from_camera: float = 0.45  # Distance in meters
@export var view_margin_degrees: float = 15.0  # Margin from edge of view in degrees
@export var follow_smoothing: float = 3.0  # Higher = smoother but slower follow
@export var push_smoothing: float = 1.5  # Higher = smoother but faster push-back
@export var look_ahead_factor: float = 0.2  # Anticipate head movement (0-1)
@export var position_offset: Vector3 = Vector3.ZERO # Static offset to the panels position

var _camera: Camera3D
var _max_horizontal_angle: float
var _max_vertical_angle: float
var _last_camera_rotation: Basis
var _camera_angular_velocity: Vector3 = Vector3.ZERO
var _panel_mesh: MeshInstance3D

func _ready() -> void:
  # Find camera
  _camera = get_viewport().get_camera_3d()
  if !_camera:
    push_error("FloatingViewPanel: Cannot find camera!")
    return
  
  # Calculate view limits
  _update_view_limits()
  
  # Set up the panel mesh and interaction area
  _setup_panel()
  
  # Initial positioning
  _update_position(0)
  
  # Store initial camera rotation for velocity calculation
  _last_camera_rotation = _camera.global_transform.basis
  
  print("FloatingViewPanel initialized")

func _update_view_limits() -> void:
  # Convert margin from degrees to radians
  var margin_radians = deg_to_rad(view_margin_degrees)
  
  # Calculate the angles based on panel dimensions and distance
  var half_width_angle = atan(panel_width * 0.5 / distance_from_camera)
  var half_height_angle = atan(panel_height * 0.5 / distance_from_camera)
  
  # Using Quest 3 FOV values here
  var horizontal_fov = deg_to_rad(96)
  var vertical_fov = deg_to_rad(84)
  
  # Calculate max angles before the panel gets pushed back
  _max_horizontal_angle = (horizontal_fov * 0.5) - half_width_angle - margin_radians
  _max_vertical_angle = (vertical_fov * 0.5) - half_height_angle - margin_radians

func _setup_panel() -> void:
  # Create panel mesh if it doesn't exist
  if !has_node("PanelMesh"):
    _panel_mesh = MeshInstance3D.new()
    _panel_mesh.name = "PanelMesh"
    add_child(_panel_mesh)
    
    var quad = QuadMesh.new()
    quad.size = Vector2(panel_width, panel_height)
    _panel_mesh.mesh = quad
    
    # Apply material
    if panel_material:
      _panel_mesh.material_override = panel_material
    else:
      var material = StandardMaterial3D.new()
      material.albedo_color = panel_color
      material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
      _panel_mesh.material_override = material
  else:
    _panel_mesh = $PanelMesh

func _process(delta: float) -> void:
  if !_camera:
    return
  
  # Update camera angular velocity for look-ahead
  var current_rotation = _camera.global_transform.basis
  var rotation_delta = current_rotation * _last_camera_rotation.inverse()
  var euler_delta = rotation_delta.get_euler()
  _camera_angular_velocity = euler_delta / delta if delta > 0 else Vector3.ZERO
  _last_camera_rotation = current_rotation

  _update_position(delta)
  _face_camera()

func _update_position(delta: float) -> void:
  # Get camera position and orientation
  var camera_pos = _camera.global_transform.origin + position_offset
  var camera_forward = -_camera.global_transform.basis.z.normalized()
  var camera_up = _camera.global_transform.basis.y.normalized()
  var camera_right = _camera.global_transform.basis.x.normalized()
  
  # Apply look-ahead based on angular velocity if movement is significant
  if look_ahead_factor > 0 && delta > 0 && _camera_angular_velocity.length() > 0.1:
    camera_forward = camera_forward.rotated(camera_up, -_camera_angular_velocity.y * delta * look_ahead_factor)
  
  # Desired position in front of camera
  var desired_position = camera_pos + (camera_forward * distance_from_camera)
  
  # Current position relative to camera
  var to_panel = global_transform.origin - camera_pos
  var current_direction = to_panel.normalized()
  var forward_dot = current_direction.dot(camera_forward)
  
  # Check if panel is in front of camera
  if forward_dot > 0.0:
    # Calculate horizontal and vertical angles
    var right_component = current_direction.dot(camera_right)
    var up_component = current_direction.dot(camera_up)
    
    var horizontal_angle = asin(clamp(right_component, -1.0, 1.0))
    var vertical_angle = asin(clamp(up_component, -1.0, 1.0))
    
    # Check if panel is going out of view bounds
    var exceeds_horizontal = abs(horizontal_angle) > _max_horizontal_angle
    var exceeds_vertical = abs(vertical_angle) > _max_vertical_angle
    
    if exceeds_horizontal || exceeds_vertical:
      # Adjust the angles to keep within bounds
      var adjusted_horizontal = clamp(horizontal_angle, -_max_horizontal_angle, _max_horizontal_angle)
      var adjusted_vertical = clamp(vertical_angle, -_max_vertical_angle, _max_vertical_angle)
      
      # Create adjusted direction to push panel back into view
      var adjusted_direction = camera_forward
      adjusted_direction = adjusted_direction.rotated(camera_up, adjusted_horizontal)
      adjusted_direction = adjusted_direction.rotated(camera_right, -adjusted_vertical)
      
      # Set new desired position using adjusted direction
      desired_position = camera_pos + (adjusted_direction * distance_from_camera)
      
      # Use faster smoothing when pushing back into view
      if delta > 0:
        global_transform.origin = global_transform.origin.lerp(desired_position, delta * push_smoothing)
    else:
      # Regular following with standard smoothing
      if delta > 0:
        global_transform.origin = global_transform.origin.lerp(desired_position, delta * follow_smoothing)
  else:
    # If panel is behind camera, immediately move it in front
    global_transform.origin = desired_position

func _face_camera() -> void:
  if !_camera:
    return
  
  # Get camera position and up vector
  var camera_pos = _camera.global_transform.origin + position_offset
  var up_vector = Vector3.UP
  
  # Look at camera
  look_at(camera_pos, up_vector)
  
  # Flip to face the camera correctly
  rotate_object_local(Vector3.UP, PI)

func reset_position() -> void:  
  if _camera:
    var camera_pos = _camera.global_transform.origin + position_offset
    var camera_forward = -_camera.global_transform.basis.z.normalized()
    global_transform.origin = camera_pos + (camera_forward * distance_from_camera)
    _face_camera()
