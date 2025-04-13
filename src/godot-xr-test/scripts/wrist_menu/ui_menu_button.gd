class_name UIMenuButton extends Node3D

signal pressed

func _ready() -> void:
  $InteractionArea.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
  pressed.emit()
