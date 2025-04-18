class_name SignalResponder extends Node

# Response actions
enum ResponseActionType {
    NONE,
    SHOW_HIDE,           # Show or hide a node
    ENABLE_DISABLE,      # Enable of disable the processing of a node
    CHANGE_MATERIAL,     # Change material on a mesh
    PLAY_SOUND,          # Play an audio file
    PLAY_ANIMATION,      # Play an animation
    TOGGLE_VISIBILITY,   # Toggle visibility
    EMIT_PARTICLES,      # Emit particles
    LOAD_SCENE,          # Load a scene
    SPAWN_OBJECT,        # Spawn an object
    TELEPORT,            # Teleport an object
    CUSTOM_FUNCTION,     # Call a custom function
    TOGGLE_VIDEO_PLAYBACK, # Toggle video player playback
    TOGGLE_MATERIALS     # Toggle between two materials
}

@export_category("Event Response Configuration")
@export var signal_name: String
@export var action_type: ResponseActionType = ResponseActionType.NONE

# Target configuration
@export_category("Action Targets")
@export var target_node: Node
@export var target_material: Material
@export var target_material_2: Material
@export var target_audio: AudioStream
@export var target_animation: String
@export var target_scene: PackedScene
@export var target_particles: GPUParticles3D
@export var target_position: Node3D
@export var target_function: String
@export var custom_args: Array = []

# Action parameters
@export_category("Action Parameters")
@export var show: bool = true       # For SHOW_HIDE and ENABLE_DISABLE
@export var delay: float = 0.0      # Delay before action
@export var apply_to_children: bool = true  # For CHANGE_MATERIAL - apply to all child meshes

# State tracking
var using_material_1: bool = false  # Track which material is active for toggle

@onready var parent: Node = get_parent()

func _ready() -> void:
  if signal_name.is_empty():
    return
  
  if parent.has_signal(signal_name):
    parent.connect(signal_name, _on_signal_received)

func _on_signal_received(_arg1=null, _arg2=null, _arg3=null, _arg4=null) -> void:
  if delay > 0:
    var timer = get_tree().create_timer(delay)
    timer.timeout.connect(_execute_action)
  else:
    _execute_action()
  
func _execute_action() -> void:
  match action_type:
    ResponseActionType.SHOW_HIDE:
      target_node.visible = show
      
    ResponseActionType.ENABLE_DISABLE:
      target_node.visible = show
      target_node.process_mode = PROCESS_MODE_INHERIT if show else PROCESS_MODE_DISABLED
    
    ResponseActionType.TOGGLE_VISIBILITY:
      target_node.visible = !target_node.visible
                
    ResponseActionType.CHANGE_MATERIAL:
      if target_node:
        if target_node is MeshInstance3D:
          target_node.material_override = target_material
        
        if apply_to_children:
          _apply_material_to_children(target_node, target_material)
  
    ResponseActionType.TOGGLE_MATERIALS:
      if target_node:
        # Determine which material to apply
        var material_to_apply = target_material_2 if using_material_1 else target_material
        
        # Apply the material
        if target_node is MeshInstance3D:
          target_node.material_override = material_to_apply
        
        if apply_to_children:
          _apply_material_to_children(target_node, material_to_apply)
        
        # Toggle the state for next time
        using_material_1 = !using_material_1
    
    ResponseActionType.PLAY_SOUND:
      if target_node is AudioStreamPlayer3D and target_audio:
        target_node.stream = target_audio
        target_node.play()
                
    ResponseActionType.PLAY_ANIMATION:
      if target_node is AnimationPlayer and target_animation:
        target_node.play(target_animation)
                
    ResponseActionType.EMIT_PARTICLES:
      if target_particles:
        target_particles.emitting = true
    
    ResponseActionType.LOAD_SCENE:
      if target_scene:
        get_tree().change_scene_to_packed(target_scene)
                
    ResponseActionType.SPAWN_OBJECT:
      if target_scene and target_position:
        var instance = target_scene.instantiate()
        target_position.add_child(instance)
        instance.global_position = target_position.global_position
                
    ResponseActionType.TELEPORT:
      if target_node and target_position:
        target_node.global_position = target_position.global_position
    
    ResponseActionType.CUSTOM_FUNCTION:
      if target_node and target_function and target_node.has_method(target_function):
        if custom_args.size() > 0:
          target_node.callv(target_function, custom_args)
        else:
          target_node.call(target_function)
          
    ResponseActionType.TOGGLE_VIDEO_PLAYBACK:
      if target_node and target_node is VideoStreamPlayer:
        if target_node.is_playing():
          target_node.pause()
        else:
          target_node.play()

# Recursively apply material to all child meshes
func _apply_material_to_children(node: Node, material: Material) -> void:
  for child in node.get_children():
    if child is MeshInstance3D:
      child.material_override = material
    
    # Continue recursion if the child has children
    if child.get_child_count() > 0:
      _apply_material_to_children(child, material)
