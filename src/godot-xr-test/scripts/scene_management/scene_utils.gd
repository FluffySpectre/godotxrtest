class_name SceneUtils

static func get_base_scene(node: Node) -> BaseScene:
  # Walk up the tree from the provided node looking for a BaseScene
  var current_node: Node = node
  while current_node:
    if current_node is BaseScene:
      return current_node as BaseScene
    current_node = current_node.get_parent()
  return null
