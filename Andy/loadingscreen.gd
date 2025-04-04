extends Control  # 或 extends CanvasLayer, 视你根节点类型而定

@onready var progress_bar: ProgressBar = $ProgressBar

func update_progress(value: float):
	# 这里假设你有一个 ProgressBar 或 Label, 设置进度条的 value
	# value: 0.0~1.0（脚本传进来的进度百分比）
	if progress_bar:
		progress_bar.value = value * 100  # 假设进度范围是0到100
