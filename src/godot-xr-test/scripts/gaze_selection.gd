class_name GazeSelection extends Node3D

# Reference to the XR camera (head)
@export var xr_camera: XRCamera3D
# Maximum distance for the gaze ray
@export var max_distance: float = 10.0
# Layer mask for interactable objects
@export_flags_3d_physics var interaction_mask: int = 1

# Multi-ring raycast configuration
@export_group("Raycast Configuration")
# Number of rays in the inner ring
@export var inner_ring_ray_count: int = 8
# Radius of the inner ring (angle in degrees)
@export var inner_ring_radius: float = 2.0
# Number of rays in the outer ring
@export var outer_ring_ray_count: int = 12
# Radius of the outer ring (angle in degrees)
@export var outer_ring_radius: float = 10.0

@export_group("Selection Behavior")
# Use multiple raycasts for small objects (more reliable)
@export var use_cylinder_cast: bool = true
# Number of circle subdivisions for cylinder cast
@export var cylinder_subdivisions: int = 4
# Radius of cylinder in meters
@export var cylinder_radius: float = 0.05
# Time in seconds before a selection can change
@export var selection_persistence: float = 0.15
# Weight for prioritizing objects hit by the center ray
@export var center_ray_weight: float = 3.0
# Weight for prioritizing objects at nearer distances
@export var distance_weight: float = 1.0
# Enable sticky selection (once selected, objects remain selected more easily)
@export var sticky_selection: bool = true
# If selected, additional weight applied to current selection
@export var sticky_weight: float = 2.0

# Reference to the currently selected object
var selected_object: InteractableObject = null
# Timer for selection persistence
var selection_timer: float = 0.0
# Last frame's candidates with scores
var last_frame_candidates = {}

func _ready() -> void:
  print("GazeSelection initialized with camera: ", xr_camera.name if xr_camera else "None")

func _physics_process(delta) -> void:
  # Update selection timer
  if selection_timer > 0:
    selection_timer -= delta
  
  # Update selection based on camera gaze
  _update_selection()

func _find_interactable_parent(node) -> InteractableObject:
  # Try to find the InteractableObject parent
  var current = node
  while current and not current is InteractableObject:
    current = current.get_parent()
  
  return current if current is InteractableObject else null

func _cast_basic_ray(from, to) -> Dictionary:
  var space_state = get_world_3d().direct_space_state
  var query = PhysicsRayQueryParameters3D.create(from, to)
  query.collision_mask = interaction_mask
  query.collide_with_areas = true
  
  var result = space_state.intersect_ray(query)
  if result and result.collider:
    var interactable = _find_interactable_parent(result.collider)
    if interactable:
      var distance = (result.position - from).length()
      return {"object": interactable, "distance": distance}
  
  return {}

func _cast_ray(from, direction, weight = 1.0) -> Dictionary:
  var to = from + (direction * max_distance)
  
  # If cylinder cast is enabled, cast multiple rays in a cylinder shape
  if use_cylinder_cast:
    var ray_results = []
    
    # Cast center ray first
    var center_result = _cast_basic_ray(from, to)
    if not center_result.is_empty():
      ray_results.append(center_result)
    
    # Cast rays in circular pattern to simulate a cylinder
    if cylinder_subdivisions > 0:
      var up = direction.cross(Vector3.UP).normalized()
      if up.length() < 0.001:  # If direction is parallel to UP
        up = direction.cross(Vector3.RIGHT).normalized()
      var right = direction.cross(up).normalized()
      
      for i in range(cylinder_subdivisions):
        var angle = (2.0 * PI * i) / cylinder_subdivisions
        var offset = (right * cos(angle) + up * sin(angle)) * cylinder_radius
        
        # Cast ray from the perimeter of the circle
        var cylinder_result = _cast_basic_ray(from + offset, to + offset)
        if not cylinder_result.is_empty():
          ray_results.append(cylinder_result)
    
    # If we got any hits, return the closest one
    if ray_results.size() > 0:
      # Sort by distance
      ray_results.sort_custom(func(a, b): return a.distance < b.distance)
      var closest = ray_results[0]
      closest.weight = weight
      return closest
  
  # Fallback to standard raycast
  var result = _cast_basic_ray(from, to)
  if not result.is_empty():
    result.weight = weight
    return result
  
  return {}

func _score_candidates(candidates) -> Dictionary:
  var scores = {}
  var min_distance = INF
  var max_distance = 0
  
  # Find distance range for normalization
  for candidate in candidates:
    min_distance = min(min_distance, candidate.distance)
    max_distance = max(max_distance, candidate.distance)
  
  # Calculate distance range for normalization
  var distance_range = max_distance - min_distance
  if distance_range <= 0:
    distance_range = 1.0
  
  # Score each candidate
  for candidate in candidates:
    var obj = candidate.object
    var base_score = candidate.weight
    
    # Add distance-based score (closer is better)
    if distance_range > 0:
      var normalized_distance = (candidate.distance - min_distance) / distance_range
      base_score += distance_weight * (1.0 - normalized_distance)
    
    # Add sticky selection bonus
    if sticky_selection and selected_object == obj:
      base_score += sticky_weight
    
    # Store the score
    if obj in scores:
      scores[obj] = max(scores[obj], base_score)
    else:
      scores[obj] = base_score
  
  return scores

func _update_selection() -> void:
  if !xr_camera or selection_timer > 0:
    return
  
  var from = xr_camera.global_transform.origin
  var forward = -xr_camera.global_transform.basis.z
  var up = xr_camera.global_transform.basis.y
  var right = xr_camera.global_transform.basis.x
  
  # Collect all ray hits
  var candidates = []
  
  # Cast center ray (highest priority)
  var center_hit = _cast_ray(from, forward, center_ray_weight)
  if not center_hit.is_empty():
    candidates.append(center_hit)
  
  # Cast inner ring rays
  if inner_ring_ray_count > 0:
    var radius_rad = deg_to_rad(inner_ring_radius)
    for i in range(inner_ring_ray_count):
      var angle = (2.0 * PI * i) / inner_ring_ray_count
      var offset_dir = forward.rotated(up, radius_rad * sin(angle))
      offset_dir = offset_dir.rotated(right, radius_rad * cos(angle))
      offset_dir = offset_dir.normalized()
      
      var hit = _cast_ray(from, offset_dir, 1.0)
      if not hit.is_empty():
        candidates.append(hit)
  
  # Cast outer ring rays
  if outer_ring_ray_count > 0:
    var radius_rad = deg_to_rad(outer_ring_radius)
    for i in range(outer_ring_ray_count):
      var angle = (2.0 * PI * i) / outer_ring_ray_count
      var offset_dir = forward.rotated(up, radius_rad * sin(angle))
      offset_dir = offset_dir.rotated(right, radius_rad * cos(angle))
      offset_dir = offset_dir.normalized()
      
      var hit = _cast_ray(from, offset_dir, 0.7)  # Lower weight for outer ring
      if not hit.is_empty():
        candidates.append(hit)
  
  # Score candidates to find the best one
  var new_selection = null
  
  if candidates.size() > 0:
    var scores = _score_candidates(candidates)
    
    # Find highest scoring object
    var highest_score = -INF
    for obj in scores:
      if scores[obj] > highest_score:
        highest_score = scores[obj]
        new_selection = obj
  
  # Maintain some selection stability based on previous frame if nothing was found
  if new_selection == null and last_frame_candidates.size() > 0:
    # Continue using previous selection for stability if recently selected
    if selected_object in last_frame_candidates:
      new_selection = selected_object
  
  # Store this frame's candidates for next frame
  last_frame_candidates.clear()
  for candidate in candidates:
    last_frame_candidates[candidate.object] = true
  
  # Update selection if changed
  if new_selection != selected_object:
    # Deselect current object
    if selected_object:
      selected_object.set_selected(false)
    
    # Select new object
    selected_object = new_selection
    if selected_object:
      selected_object.set_selected(true)
    
    # Reset selection persistence timer
    selection_timer = selection_persistence
