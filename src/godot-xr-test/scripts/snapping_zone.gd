class_name SnappingZone extends Node3D

# Signals
signal object_entered(object: InteractableObject)
signal object_exited(object: InteractableObject)
signal object_snapped(object: InteractableObject)
signal object_unsnapped(object: InteractableObject)

# Properties
@export var enabled: bool = true : set = set_enabled, get = get_enabled
@export var highlight_on_proximity: bool = true
@export var auto_snap_when_close: bool = false
@export var snap_distance: float = 0.3  # Distance when auto-snap activates
@export var snap_offset: Vector3 = Vector3.ZERO
@export var snap_rotation: Vector3 = Vector3.ZERO
@export var snap_scale: Vector3 = Vector3.ONE

@export_group("Object Filtering")
@export var object_filter_tag: String = ""  # Only snap objects with this tag
@export var single_object: bool = false  # Only one object can be snapped at a time

@export_group("Visuals")
@export var inactive_material: Material
@export var proximity_material: Material
@export var active_material: Material

@export_group("Audio")
@export var snap_sound: AudioStream
@export var unsnap_sound: AudioStream

# References
@onready var trigger_area: Area3D = $TriggerArea
@onready var snap_position: Node3D = $SnapPosition
@onready var visual_mesh: MeshInstance3D = $VisualMesh
@onready var sound_player: AudioStreamPlayer3D = $SoundPlayer

# State variables
var snapped_object: InteractableObject = null
var objects_in_zone: Array[InteractableObject] = []
var is_highlighted: bool = false
var _enabled: bool = true
var _snapped_object_original_enabled_state: bool = true

func set_enabled(value: bool) -> void:
  if _enabled == value:
    return
    
  _enabled = value
  
  # Propagate enabled state to snapped object
  if snapped_object:
    if _enabled:
      snapped_object.enabled = _snapped_object_original_enabled_state
    else:
      snapped_object.enabled = false

func get_enabled() -> bool:
  return _enabled

func _ready() -> void:
  # Connect area signals for both bodies and areas
  trigger_area.body_entered.connect(_on_body_entered)
  trigger_area.body_exited.connect(_on_body_exited)
  trigger_area.area_entered.connect(_on_area_entered)
  trigger_area.area_exited.connect(_on_area_exited)
  
  # Set initial material
  if visual_mesh && inactive_material:
    visual_mesh.material_override = inactive_material
    
  # Ensure audio player exists
  if !sound_player && (snap_sound || unsnap_sound):
    sound_player = AudioStreamPlayer3D.new()
    add_child(sound_player)

func _process(_delta: float) -> void:
  if enabled && auto_snap_when_close && !snapped_object:
    _check_for_auto_snap()

func _check_for_auto_snap() -> void:
  # Check all objects in zone for potential auto-snap
  for object in objects_in_zone:
    if can_snap_object(object):
      var distance = object.global_position.distance_to(get_snap_position())
      if distance <= snap_distance:
        snap_object(object)
        break

func get_snap_position() -> Vector3:
  return snap_position.global_position + snap_offset

func get_snap_rotation() -> Vector3:
  return snap_position.global_rotation + snap_rotation

func get_snap_transform() -> Transform3D:
  var transform = Transform3D()
  transform.origin = get_snap_position()
  transform.basis = Basis.from_euler(get_snap_rotation())
  
  # Apply snap scale
  if snap_scale != Vector3.ONE:
    transform.basis = transform.basis.scaled(snap_scale)
  
  return transform

func can_snap_object(object: InteractableObject) -> bool:
  # Check if object is valid for snapping
  if !object || (single_object && snapped_object):
    return false
    
  # Check if object matches filter tag if one is set
  if object_filter_tag && !object.tags.has(object_filter_tag) && object.tag != object_filter_tag:
    return false

  return true

func snap_object(object: InteractableObject) -> bool:
  if !enabled || !can_snap_object(object):
    return false
  
  # If we already have an object snapped and only one is allowed, unsnap it first
  if single_object && snapped_object && snapped_object != object:
    unsnap_object(snapped_object)
  
  # Store original enabled state before modifying it
  _snapped_object_original_enabled_state = object.enabled
  
  # Set as snapped
  snapped_object = object
  
  # Tell the object it's been snapped
  object.snap_to_zone(self)
  
  # Propagate zone's enabled state to the snapped object
  object.enabled = enabled
  
  # Update visual state
  _update_visual_state()
  
  # Play sound
  if sound_player && snap_sound:
    sound_player.stream = snap_sound
    sound_player.play()
  
  # Emit signal
  emit_signal("object_snapped", object)
  
  return true

func unsnap_object(object: InteractableObject) -> bool:
  if !object || snapped_object != object:
    return false
  
  # Restore original enabled state
  object.enabled = _snapped_object_original_enabled_state
  
  # Clear reference
  snapped_object = null
  
  # Tell object it's been unsnapped
  object.unsnap_from_zone()
  
  # Update visual state
  _update_visual_state()
  
  # Play sound
  if sound_player && unsnap_sound:
    sound_player.stream = unsnap_sound
    sound_player.play()
  
  # Emit signal
  emit_signal("object_unsnapped", object)
  
  return true

func _get_interactable_from_node(node: Node) -> InteractableObject:
  # If it's directly an InteractableObject
  if node is InteractableObject:
    return node
    
  # If it's an Area3D with a meta reference to its parent
  if node is Area3D && node.has_meta("parent_interactable"):
    return node.get_meta("parent_interactable")
    
  # If it has an InteractableObject parent
  var parent = node.get_parent()
  while parent:
    if parent is InteractableObject:
      return parent
    parent = parent.get_parent()
    
  return null

func _on_body_entered(body: Node) -> void:
  if !enabled:
    return
    
  var object = _get_interactable_from_node(body)
  if object:
    _handle_object_entered(object)

func _on_body_exited(body: Node) -> void:
  var object = _get_interactable_from_node(body)
  if object:
    _handle_object_exited(object)

func _on_area_entered(area: Area3D) -> void:
  if !enabled:
    return
    
  var object = _get_interactable_from_node(area)
  if object:
    _handle_object_entered(object)

func _on_area_exited(area: Area3D) -> void:
  var object = _get_interactable_from_node(area)
  if object:
    _handle_object_exited(object)

func _handle_object_entered(object: InteractableObject) -> void:
  # Add to tracked objects
  if !objects_in_zone.has(object):
    if !can_snap_object(object):
      return
    
    objects_in_zone.append(object)
    
    # Notify object it entered a snapping zone
    object.entered_snapping_zone(self)
    
    # Update visual highlight
    if highlight_on_proximity && objects_in_zone.size() > 0 && !snapped_object:
      is_highlighted = true
      _update_visual_state()
    
    # Emit signal
    emit_signal("object_entered", object)

func _handle_object_exited(object: InteractableObject) -> void:
  # Remove from tracked objects
  if objects_in_zone.has(object):
    objects_in_zone.erase(object)
    
    # Notify object it exited a snapping zone
    object.exited_snapping_zone(self)
    
    # Update visual highlight
    if highlight_on_proximity && objects_in_zone.size() == 0 && !snapped_object:
      is_highlighted = false
      _update_visual_state()
    
    # Emit signal
    emit_signal("object_exited", object)

func _update_visual_state() -> void:
  if !visual_mesh:
    return
  
  # Choose material based on state
  if snapped_object && active_material:
    visual_mesh.material_override = active_material
  elif is_highlighted && proximity_material:
    visual_mesh.material_override = proximity_material
  elif inactive_material:
    visual_mesh.material_override = inactive_material
