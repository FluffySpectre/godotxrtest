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

# Current state
var is_pressed: bool = false
var is_hovering: bool = false
var pressing_finger: Node3D = null
var press_start_position: Vector3
var initial_button_position: Vector3
var current_animation_tween: Tween
var material_instance: BaseMaterial3D

# Components
@onready var mesh_instance: MeshInstance3D = $ButtonMesh
@onready var collision_shape: CollisionShape3D = $InteractionArea/CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

func press() -> void:
  if not is_pressed:
    _press_button()

func release() -> void:
  if is_pressed:
    _release_button()

func _ready() -> void:
  _setup_button_mesh()
  
  # Store initial position for animation
  initial_button_position = mesh_instance.position
  
  # Connect signals
  interaction_area.body_entered.connect(_on_body_entered)
  interaction_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
  if pressing_finger and is_hovering:
    _check_press_state()

func _setup_button_mesh() -> void:
  # Configure material
  material_instance = button_material.duplicate()
  material_instance.albedo_color = normal_color
  mesh_instance.material_override = material_instance

func _on_body_entered(body: Node3D) -> void:
  is_hovering = true
  pressing_finger = body
  press_start_position = body.global_position
  
  # Change material to hover color
  material_instance.albedo_color = hover_color
  
  emit_signal("hover_started")

func _on_body_exited(body: Node3D) -> void:
  if body == pressing_finger:
    # Reset state
    is_hovering = false
    
    if is_pressed:
      _release_button()
      
    pressing_finger = null
    
    # Reset material to normal color
    material_instance.albedo_color = normal_color
    
    emit_signal("hover_ended")

func _check_press_state() -> void:
  if not pressing_finger:
    return
    
  # Get current finger position
  var current_finger_pos = pressing_finger.global_position
  
  # Convert to local coordinate system for y-depth measurement
  var local_start = to_local(press_start_position)
  var local_current = to_local(current_finger_pos)
  
  # Calculate press depth from initial contact
  var press_distance = local_start.y - local_current.y
  
  if not is_pressed and press_distance > press_threshold:
    _press_button()
  elif is_pressed and press_distance < press_threshold * 0.5:
    _release_button()

func _press_button() -> void:
  if is_pressed:
    return
    
  is_pressed = true
  
  # Cancel any current animation
  if current_animation_tween and current_animation_tween.is_valid():
    current_animation_tween.kill()
  
  # Animate button press
  current_animation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
  current_animation_tween.tween_property(mesh_instance, "position:y", 
    initial_button_position.y - press_depth, animation_speed)
  
  # Change color
  material_instance.albedo_color = press_color
  
  # Play sound if enabled
  if play_sound and audio_player and sound_effect:
    audio_player.stream = sound_effect
    audio_player.play()
  
  # Emit pressed signal
  emit_signal("pressed")
  
func _release_button() -> void:
  if not is_pressed:
    return
    
  is_pressed = false
  
  # Cancel any current animation
  if current_animation_tween and current_animation_tween.is_valid():
    current_animation_tween.kill()
  
  # Animate button release
  current_animation_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
  current_animation_tween.tween_property(mesh_instance, "position:y", 
    initial_button_position.y, animation_speed * 1.5)
  
  # Change color to hover since finger is still hovering
  material_instance.albedo_color = hover_color
  
  # Emit released signal
  emit_signal("released")
