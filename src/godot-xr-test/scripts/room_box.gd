class_name RoomBox extends Node3D

@export var box_material: StandardMaterial3D
@export var fade_duration: float = 1.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _fade_tween: Tween
var _material_instance: StandardMaterial3D
var _max_alpha: float
var _is_fading_in: bool
var _is_fading: bool

func _ready() -> void:
  if mesh_instance:
    _material_instance = box_material.duplicate()
    _max_alpha = _material_instance.albedo_color.a
    #_material_instance.albedo_color.a = 0.0
    mesh_instance.material_override = _material_instance

func fade_in() -> void:
  if _fade_tween && _fade_tween.is_valid():
    _fade_tween.finished.disconnect(_on_tween_finished)
    _fade_tween.kill()
    
  _fade_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
  _fade_tween.tween_property(_material_instance, "albedo_color:a", _max_alpha, fade_duration)
  _fade_tween.finished.connect(_on_tween_finished)
  
  _is_fading = true
  _is_fading_in = true
  
func fade_out() -> void:
  if _fade_tween && _fade_tween.is_valid():
    _fade_tween.finished.disconnect(_on_tween_finished)
    _fade_tween.kill()
  
  _fade_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
  _fade_tween.tween_property(_material_instance, "albedo_color:a", 0.0, fade_duration)
  _fade_tween.finished.connect(_on_tween_finished)
  
  _is_fading = true
  _is_fading_in = false

func is_fading_in() -> bool:
  return _is_fading && _is_fading_in

func is_fading_out() -> bool:
  return _is_fading && !_is_fading_in
  
func _on_tween_finished() -> void:
  _is_fading = false
