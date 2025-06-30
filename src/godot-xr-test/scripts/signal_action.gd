@icon("res://assets/icons/signal_action.svg")
class_name SignalAction extends Node

enum ActionType {
  NONE,                  ## No action
  SHOW_HIDE,             ## Show or hide a node
  ENABLE_DISABLE,        ## Enable of disable the processing of a node
  CHANGE_MATERIAL,       ## Change material on a mesh
  PLAY_SOUND,            ## Play an audio file
  PLAY_ANIMATION,        ## Play an animation
  TOGGLE_VISIBILITY,     ## Toggle visibility
  TOGGLE_ENABLE,         ## Toggle enable state
  EMIT_PARTICLES,        ## Emit particles
  LOAD_SCENE,            ## Load a scene
  SPAWN_OBJECT,          ## Spawn an object
  TELEPORT,              ## Teleport an object
  CUSTOM_FUNCTION,       ## Call a custom function
  TOGGLE_VIDEO_PLAYBACK, ## Toggle video player playback
  TOGGLE_MATERIALS       ## Toggle between two materials
}

# Action configuration
@export var action_type: ActionType = ActionType.NONE
@export var delay: float = 0.0
@export_multiline var description: String = ""

# Target configuration
@export_group("Target Configuration")
@export var target_node: Node
@export var target_material: Material
@export var target_material_2: Material
@export var target_audio: AudioStream
@export var target_animation: String
@export var target_scene: PackedScene
@export_file("*.tscn") var target_scene_load: String
@export var target_particles: Node
@export var target_position: Node3D
@export var target_function: String
@export var custom_args: Array = []

# Action parameters
@export_group("Action Parameters")
@export var show: bool = true       # For SHOW_HIDE and ENABLE_DISABLE
@export var apply_to_children: bool = true  # For CHANGE_MATERIAL - apply to all child meshes
@export_file("*.tscn") var scene_data: String # For LOAD_SCENE - Additional data for the new scene

# State tracking
var using_material_1: bool = false  # Track which material is active for toggle

func execute() -> void:
  if !_can_execute():
    push_error("SignalAction: Target node not found")
    return
    
  match action_type:
    ActionType.NONE:
      pass
      
    ActionType.SHOW_HIDE:
      target_node.visible = show
      
    ActionType.ENABLE_DISABLE:
      target_node.visible = show
      target_node.process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
    
    ActionType.TOGGLE_VISIBILITY:
      target_node.visible = !target_node.visible
      
    ActionType.TOGGLE_ENABLE:
      var new_state = !target_node.visible
      target_node.visible = new_state
      target_node.process_mode = Node.PROCESS_MODE_INHERIT if new_state else Node.PROCESS_MODE_DISABLED
          
    ActionType.CHANGE_MATERIAL:
      if target_node is MeshInstance3D:
        target_node.material_override = target_material
      
      if apply_to_children:
        _apply_material_to_children(target_node, target_material)
  
    ActionType.TOGGLE_MATERIALS:
      var material_to_apply = target_material_2 if using_material_1 else target_material
      
      if target_node is MeshInstance3D:
        target_node.material_override = material_to_apply
      
      if apply_to_children:
        _apply_material_to_children(target_node, material_to_apply)
      
      using_material_1 = !using_material_1
    
    ActionType.PLAY_SOUND:
      if target_node is AudioStreamPlayer or target_node is AudioStreamPlayer3D:
        if target_audio:
          target_node.stream = target_audio
        target_node.play()
          
    ActionType.PLAY_ANIMATION:
      if target_node is AnimationPlayer and target_animation:
        target_node.play(target_animation)
          
    ActionType.EMIT_PARTICLES:
      var particles = target_particles
      if particles is GPUParticles3D or particles is GPUParticles2D:
        particles.emitting = true
    
    ActionType.LOAD_SCENE:
      if target_scene_load:
        var base_scene = SceneUtils.get_base_scene(self)
        base_scene.request_load_scene_f(target_scene_load, scene_data)
        
    ActionType.SPAWN_OBJECT:
      if target_scene:
        var position_node = target_position
        if position_node:
          var instance = target_scene.instantiate()
          position_node.add_child(instance)
          if instance is Node3D and position_node is Node3D:
            instance.global_position = position_node.global_position
          elif instance is Node2D and position_node is Node2D:
            instance.global_position = position_node.global_position
          
    ActionType.TELEPORT:
      var position_node = target_position
      if target_node and position_node:
        if target_node is Node3D and position_node is Node3D:
          target_node.global_position = position_node.global_position
        elif target_node is Node2D and position_node is Node2D:
          target_node.global_position = position_node.global_position
    
    ActionType.CUSTOM_FUNCTION:
      if target_function and target_node.has_method(target_function):
        if custom_args.size() > 0:
          target_node.callv(target_function, custom_args)
        else:
          target_node.call(target_function)
        
    ActionType.TOGGLE_VIDEO_PLAYBACK:
      if target_node is VideoStreamPlayer:
        if target_node.is_playing():
          target_node.pause()
        else:
          target_node.play()

func _can_execute() -> bool:
  # Load scene doesn't need a target node
  if action_type == ActionType.LOAD_SCENE:
    return true
  
  return target_node && action_type != ActionType.NONE

# Recursively apply material to all child meshes
func _apply_material_to_children(node: Node, material: Material) -> void:
  for child in node.get_children():
    if child is MeshInstance3D:
      child.material_override = material
    
    # Continue recursion if the child has children
    if child.get_child_count() > 0:
      _apply_material_to_children(child, material)
