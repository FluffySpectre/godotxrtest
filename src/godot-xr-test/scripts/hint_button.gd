class_name HintButton extends Node3D

var tween: Tween
var original_rotation: Vector3

func _ready() -> void:
  original_rotation = rotation
  start_wiggle()

func start_wiggle() -> void:
  tween = create_tween()
  tween.set_loops()
  create_wiggle_sequence()

func create_wiggle_sequence() -> void:
  var wiggle_angle = deg_to_rad(15)
  var wiggle_duration = 0.05
  var pause_duration = 3.0
  
  tween.tween_property(self, "rotation", original_rotation + Vector3(0, 0, wiggle_angle), wiggle_duration)
  tween.tween_property(self, "rotation", original_rotation, wiggle_duration)
  tween.tween_property(self, "rotation", original_rotation + Vector3(0, 0, -wiggle_angle), wiggle_duration)
  tween.tween_property(self, "rotation", original_rotation, wiggle_duration)
  tween.tween_property(self, "rotation", original_rotation + Vector3(0, 0, wiggle_angle), wiggle_duration)
  tween.tween_property(self, "rotation", original_rotation, wiggle_duration)
  
  # Wait before repeating
  tween.tween_interval(pause_duration)
