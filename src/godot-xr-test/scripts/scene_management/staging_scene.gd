class_name StagingScene extends Node3D

# Signals
signal scene_exiting(scene: BaseScene, user_data)
signal scene_loaded(scene: BaseScene, user_data)
signal scene_visible(scene: BaseScene, user_data)

@export_file("*.tscn") var main_scene: String

var current_scene: BaseScene
var current_scene_path: String

@onready var _scene_container: Node3D = $Scene
@onready var _xr_manager: XRManager = $XRManager

var _tween: Tween

func _ready() -> void:
  load_scene(main_scene)

func load_scene(scene_path: String, user_data = null) -> void:
  # Start the threaded loading of the scene. If the scene is already cached
  # then this will finish immediately with THREAD_LOAD_LOADED
  ResourceLoader.load_threaded_request(scene_path)
  
  # If a current scene is visible then fade it out and unload it
  if current_scene:
    # Report pre-exiting and remove the scene signals
    current_scene.scene_pre_exiting(user_data)
    _remove_signals(current_scene)
    
    # Fade to black
    if _tween:
      _tween.kill()
    _tween = get_tree().create_tween()
    _tween.tween_method(set_fade, 0.0, 1.0, 1.0)
    await _tween.finished
    
    # Now we remove our scene - defer the removal to avoid tree busy state
    scene_exiting.emit(current_scene, user_data)
    current_scene.scene_exiting(user_data)
    
    _scene_container.remove_child(current_scene)
    current_scene.queue_free()  
    current_scene = null
    
  if ResourceLoader.load_threaded_get_status(scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
    # Loop waiting for the scene to load
    var res: ResourceLoader.ThreadLoadStatus
    while true:
      res = ResourceLoader.load_threaded_get_status(scene_path)
      if res != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        break
      await get_tree().create_timer(0.1).timeout
    
    # Handle load error
    if res != ResourceLoader.THREAD_LOAD_LOADED:
      # Report the error to the log and console
      push_error("Error ", res, " loading resource ", scene_path)
      get_tree().quit(1)
  
  # Get the loaded scene
  var new_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)
  
  # Setup our new scene
  current_scene = new_scene.instantiate()
  current_scene_path = scene_path
  _scene_container.add_child(current_scene)
  _add_signals(current_scene)
  
  # We create a small delay here to give tracking some time to update our nodes...
  await get_tree().create_timer(0.1).timeout
  
  current_scene.scene_loaded(user_data)
  scene_loaded.emit(current_scene, user_data)
  
  # Fade to visible
  if _tween:
    _tween.kill()
  _tween = get_tree().create_tween()
  _tween.tween_method(set_fade, 1.0, 0.0, 1.0)
  await _tween.finished
  
  # Report new scene visible
  current_scene.scene_visible(user_data)
  scene_visible.emit(current_scene, user_data)

func set_fade(val: float) -> void:
  Fade.set_fade("staging", Color(0, 0, 0, val))

func _add_signals(scene: BaseScene) -> void:
  scene.request_exit_to_main.connect(_on_exit_to_main)
  scene.request_load_scene.connect(_on_load_scene)
  scene.request_reset_scene.connect(_on_reset_scene)
  scene.request_quit.connect(_on_quit)

func _remove_signals(scene: BaseScene) -> void:
  scene.request_exit_to_main.disconnect(_on_exit_to_main)
  scene.request_load_scene.disconnect(_on_load_scene)
  scene.request_reset_scene.disconnect(_on_reset_scene)
  scene.request_quit.disconnect(_on_quit)

func _on_exit_to_main() -> void:
  load_scene(main_scene)

func _on_load_scene(scene_path: String, user_data) -> void:
  load_scene(scene_path, user_data)

func _on_reset_scene(user_data) -> void:
  load_scene(current_scene_path, user_data)

func _on_quit() -> void:
  _xr_manager.end_xr()
