@tool
@icon("res://assets/icons/signal_responder.svg")
class_name SignalResponder extends Node

## DEPRECATED
enum ResponseActionType {
  NONE,                  ## No action
  SHOW_HIDE,             ## Show or hide a node
  ENABLE_DISABLE,        ## Enable of disable the processing of a node
  CHANGE_MATERIAL,       ## Change material on a mesh
  PLAY_SOUND,            ## Play an audio file
  PLAY_ANIMATION,        ## Play an animation
  TOGGLE_VISIBILITY,     ## Toggle visibility
  EMIT_PARTICLES,        ## Emit particles
  LOAD_SCENE,            ## Load a scene
  SPAWN_OBJECT,          ## Spawn an object
  TELEPORT,              ## Teleport an object
  CUSTOM_FUNCTION,       ## Call a custom function
  TOGGLE_VIDEO_PLAYBACK, ## Toggle video player playback
  TOGGLE_MATERIALS       ## Toggle between two materials
}

@export var signal_name: String

# Deprecated configuration
@export_group("DEPRECATED CONFIGURATION")
@export var action_type: ResponseActionType = ResponseActionType.NONE
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
@export var show: bool = true
@export var delay: float = 0.0
@export var apply_to_children: bool = true

@onready var _parent: Node = get_parent()

func _ready() -> void:
  if Engine.is_editor_hint():
    return
  
  if not signal_name.is_empty() and _parent.has_signal(signal_name):
    _parent.connect(signal_name, _on_signal_received)
  else:
    print("SignalResponder: Failed to connect to signal '%s' on node '%s'" % [signal_name, _parent.name])

func _on_signal_received(_arg1=null, _arg2=null, _arg3=null, _arg4=null) -> void:
  for action in get_children():
    if action is SignalAction:
      if action.delay > 0:
        var timer = get_tree().create_timer(action.delay)
        timer.timeout.connect(action.execute)
      else:
        action.execute()  

func _validate_property(_property: Dictionary) -> void:
  if action_type == ResponseActionType.NONE:
    return
  
  # Migrate the old configuration to the new one (if needed)
  var needs_migration: bool = true
  if get_child_count() > 0:
    needs_migration = !get_children().any(func(c: Node): return c is SignalAction)
  
  if needs_migration:
    # Create a new SignalAction node
    var signal_action: SignalAction = SignalAction.new()
    signal_action.name = "SignalAction"
    
    # Move configuration over to node
    var new_action_type: SignalAction.ActionType = action_type as SignalAction.ActionType
    signal_action.action_type = new_action_type
    signal_action.delay = delay
    # Target configuration
    signal_action.target_node = target_node
    signal_action.target_material = target_material
    signal_action.target_material_2 = target_material_2
    signal_action.target_audio = target_audio
    signal_action.target_animation = target_animation
    signal_action.target_scene = target_scene
    signal_action.target_particles = target_particles
    signal_action.target_position = target_position
    signal_action.target_function = target_function
    signal_action.custom_args = custom_args
    # Action parameters
    signal_action.show = show
    signal_action.apply_to_children = apply_to_children

    # Add configured node as a child
    add_child(signal_action)
    signal_action.owner = get_tree().edited_scene_root
