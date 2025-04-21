class_name PokeButton extends Node3D

# Signals
signal pressed
signal released
signal hover_started
signal hover_ended

# Button appearance and behavior settings
@export_group("Button Settings")
@export var button_material: BaseMaterial3D
@export var normal_color: Color = Color(0.2, 0.2, 0.8, 1.0)
@export var hover_color: Color = Color(0.3, 0.3, 1.0, 1.0)
@export var press_color: Color = Color(0.1, 0.1, 0.6, 1.0)
@export var press_depth: float = 0.005
@export var press_threshold: float = 0.002
@export var animation_speed: float = 0.1

# Feedback settings
@export_group("Feedback")
@export var play_sound: bool
@export var sound_effect: AudioStream

# Components
@onready var _mesh_instance: MeshInstance3D = $ButtonMesh
@onready var _interaction_area: Area3D = $InteractionArea
@onready var _audio_player: AudioStreamPlayer3D = $AudioPlayer

# Current state
var _is_pressed: bool = false
var _is_hovering: bool = false
var _pressing_finger: Node3D = null
var _press_start_position: Vector3
var _initial_button_position: Vector3
var _current_animation_tween: Tween
var _material_instance: BaseMaterial3D

func press() -> void:
  if !_is_pressed:
    _press_button()

func release() -> void:
  if _is_pressed:
    _release_button()

func _ready() -> void:
  _setup_button_mesh()
  
  # Store initial position for animation
  _initial_button_position = _mesh_instance.position
  
  # Connect signals
  _interaction_area.body_entered.connect(_on_body_entered)
  _interaction_area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
  if _pressing_finger && _is_hovering:
    _check_press_state()

func _setup_button_mesh() -> void:
  # Configure material
  _material_instance = button_material.duplicate()
  _material_instance.albedo_color = normal_color
  _mesh_instance.material_override = _material_instance

func _on_body_entered(body: Node3D) -> void:
  _is_hovering = true
  _pressing_finger = body
  _press_start_position = body.global_position
  
  # Change material to hover color
  _material_instance.albedo_color = hover_color
  
  emit_signal("hover_started")

func _on_body_exited(body: Node3D) -> void:
  if body == _pressing_finger:
    # Reset state
    _is_hovering = false
    
    if _is_pressed:
      _release_button()
      
    _pressing_finger = null
    
    # Reset material to normal color
    _material_instance.albedo_color = normal_color
    
    emit_signal("hover_ended")

func _check_press_state() -> void:
  if !_pressing_finger:
    return
    
  # Get current finger position
  var current_finger_pos = _pressing_finger.global_position
  
  # Convert to local coordinate system for y-depth measurement
  var local_start = to_local(_press_start_position)
  var local_current = to_local(current_finger_pos)
  
  # Calculate press depth from initial contact
  var press_distance = local_start.y - local_current.y
  
  if !_is_pressed && press_distance > press_threshold:
    _press_button()
  elif _is_pressed && press_distance < press_threshold * 0.5:
    _release_button()

func _press_button() -> void:
  if _is_pressed:
    return
    
  _is_pressed = true
  
  # Cancel any current animation
  if _current_animation_tween && _current_animation_tween.is_valid():
    _current_animation_tween.kill()
  
  # Animate button press
  _current_animation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
  _current_animation_tween.tween_property(_mesh_instance, "position:y", 
    _initial_button_position.y - press_depth, animation_speed)
  
  # Change color
  _material_instance.albedo_color = press_color
  
  # Play sound if enabled
  if play_sound && _audio_player && sound_effect:
    _audio_player.stream = sound_effect
    _audio_player.play()
  
  # Emit pressed signal
  emit_signal("pressed")
  
func _release_button() -> void:
  if !_is_pressed:
    return
    
  _is_pressed = false
  
  # Cancel any current animation
  if _current_animation_tween && _current_animation_tween.is_valid():
    _current_animation_tween.kill()
  
  # Animate button release
  _current_animation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
  _current_animation_tween.tween_property(_mesh_instance, "position:y", 
    _initial_button_position.y, animation_speed * 1.5)
  
  # Change color to hover since finger is still hovering
  _material_instance.albedo_color = hover_color
  
  # Emit released signal
  emit_signal("released")
