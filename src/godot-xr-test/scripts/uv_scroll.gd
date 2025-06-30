class_name UVScroll extends Node

@export var offset: Vector3 = Vector3.ZERO

@onready var _parent: MeshInstance3D = get_parent() as MeshInstance3D

func _process(delta: float) -> void:
  var material = _parent.get_active_material(0) as StandardMaterial3D
  material.uv1_offset += offset * delta
