extends Control

var callback : Callable;

func setup(t : String, cb : Callable = Callable()):
	$Panel/RichTextLabel.text = t;
	callback = cb;

func _ready():
	$Panel/Button.grab_focus();
	
func _on_button_pressed():
	if !callback.is_null():
		callback.call();
	queue_free();
