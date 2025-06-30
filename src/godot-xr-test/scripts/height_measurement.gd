class_name HeightMeasurement extends Node3D

signal completed

@export var required_height: float = 1.5
@export var height_tolerance: float = 0.05

@export_group("Feedback")
@export var measure_hint: String = "Bitte ducke dich unter diese Linie."
@export var success_hint: String = "Gut gemacht!\nDu betrittst nun den Fahrzeuginnenraum!"
@export var success_sound: AudioStream

@onready var _height_indicator: Node3D = $HeightIndicator
@onready var _hint_label: Label3D = $HintLabel
@onready var _sound_player: AudioStreamPlayer3D = $SoundPlayer

var _height_ok: bool
var _last_height_ok: bool
var _countdown: float = 4.0
var _completed: bool

func _ready() -> void:
  # Adjust the height of the indicator
  _height_indicator.global_position.y = required_height
  
  _hint_label.text = measure_hint
  _hint_label.modulate = Color.WHITE

func _process(delta: float) -> void:
  _check_user_height()
  _update_state()
  _update_countdown(delta)

func _update_countdown(delta: float) -> void:
  if !_height_ok || _completed:
    _countdown = 4.0
    return
  
  _countdown -= delta
  if _countdown > 0.0:
    _hint_label.text = success_hint + "\n" + str(int(_countdown)) + " ..."
  else:
    _completed = true
    completed.emit()

func _check_user_height() -> void:
  if !XRRig.instance.xr_camera:
    return
  
  var current_height = XRRig.instance.xr_camera.global_position.y
  
  if current_height <= (required_height - height_tolerance):
    _height_ok = true
  else:
    _height_ok = false

func _update_state() -> void:
  if _completed || _last_height_ok == _height_ok:
    return
  
  if _height_ok:
    _success_feedback()
  else:
    _measuring_feedback()
  
  _last_height_ok = _height_ok
  
func _success_feedback() -> void:
  if _sound_player && success_sound:
    _sound_player.stream = success_sound
    _sound_player.play()
  
  _hint_label.text = success_hint
  _hint_label.modulate = Color.GREEN

func _measuring_feedback() -> void:
  _hint_label.text = measure_hint
  _hint_label.modulate = Color.WHITE
