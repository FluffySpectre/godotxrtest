@icon("res://assets/icons/signal_responder.svg")
class_name SignalResponder extends Node

@export var signal_name: String

func _ready() -> void:
  var parent = get_parent()
  if not signal_name.is_empty() and parent.has_signal(signal_name):
    parent.connect(signal_name, _on_signal_received)
  else:
    print("SignalResponder: Failed to connect to signal '%s' on node '%s'" % [signal_name, parent.name])

func _on_signal_received(_arg1=null, _arg2=null, _arg3=null, _arg4=null) -> void:
  for action in get_children():
    if action is SignalAction:
      if action.delay > 0:
        var timer = get_tree().create_timer(action.delay)
        timer.timeout.connect(action.execute)
      else:
        action.execute()  
