extends Node

@export var loading_scene_path: String = "res://Andy/loadingscreen.tscn"

var _target_scene_path: String = ""      # 将要加载的目标场景路径
var _loading_ui_instance: Node = null    # Loading UI 场景的实例
var _loading_in_progress: bool = false   # 标记是否正在进行场景加载
var _progress_data: Array = []           # 用于存储加载进度百分比的数组（长度为1）

func change_scene_with_loading(scene_path: String) -> void:
	# (2) 切换到目标场景前，先加载并显示 Loading UI 场景
	if _loading_in_progress:
		return  # 如果已经在加载过程中，则不重复执行
	_loading_in_progress = true
	_target_scene_path = scene_path

	# 实例化 Loading UI 场景并添加到当前场景的顶部
	if loading_scene_path == "" or not ResourceLoader.exists(loading_scene_path, "PackedScene"):
		print("警告: 未指定有效的 Loading UI 场景路径，直接切换场景。")
		get_tree().change_scene_to_file(scene_path)  # 未设置加载界面时直接切换场景
		_loading_in_progress = false
		return
	var loading_scene_res: Resource = ResourceLoader.load(loading_scene_path)
	if loading_scene_res is PackedScene:
		_loading_ui_instance = loading_scene_res.instantiate()
		# 将 Loading UI 添加到场景树根节点，确保它显示在最上层
		get_tree().get_root().add_child(_loading_ui_instance)
		# 可选：将 Loading UI 移动到子节点列表末尾，以确保其渲染在顶层
		get_tree().get_root().move_child(_loading_ui_instance, get_tree().get_root().get_child_count() - 1)
	else:
		print("错误: 无法加载 Loading UI 场景，直接切换场景。")
		get_tree().change_scene_to_file(scene_path)
		_loading_in_progress = false
		return

	# (3) 使用 ResourceLoader.load_threaded_request() 异步请求加载目标场景
	var err: Error = ResourceLoader.load_threaded_request(_target_scene_path, "PackedScene")
	if err != OK:
		print("错误: ResourceLoader 请求加载失败: ", err)
		# 若加载请求失败，移除 Loading UI 并结束流程
		if _loading_ui_instance:
			_loading_ui_instance.queue_free()
			_loading_ui_instance = null
		_loading_in_progress = false
		return

	# 启用 _process 以轮询加载进度
	set_process(true)

func _process(delta: float) -> void:
	if not _loading_in_progress:
		return  # 只有在加载过程中才需要轮询处理

	# 轮询获取当前加载状态和进度 (progress 数组返回 [加载进度百分比]，范围0.0~1.0)
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, _progress_data)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 加载进行中：更新 Loading UI 上的进度显示（如果有进度条）
			if _loading_ui_instance and _loading_ui_instance.has_method("update_progress"):
				# 如果 Loading UI 场景脚本定义了 update_progress(percent: float)，调用它传入当前进度
				var progress_percent: float = 0.0
				if _progress_data.size() > 0:
					progress_percent = _progress_data[0]  # 获取当前进度百分比 (0~1.0)
				_loading_ui_instance.update_progress(progress_percent)
			# 如果 Loading UI 没有进度显示，则无需更新，仅保持加载界面可见即可
		ResourceLoader.THREAD_LOAD_LOADED:
			# (4) 加载完成：获取已加载的场景资源并切换场景
			var new_scene: PackedScene = ResourceLoader.load_threaded_get(_target_scene_path)
			if new_scene:
				get_tree().change_scene_to_packed(new_scene)
			else:
				print("错误: 加载的资源不是有效的场景(PackedScene)")
			# 切换完成后移除 Loading UI 界面
			if _loading_ui_instance:
				_loading_ui_instance.queue_free()
				_loading_ui_instance = null
			# 停止轮询过程
			_loading_in_progress = false
			set_process(false)
		ResourceLoader.THREAD_LOAD_FAILED:
			# 加载失败：打印错误并清理界面
			print("错误: 无法加载目标场景: ", _target_scene_path)
			if _loading_ui_instance:
				_loading_ui_instance.queue_free()
				_loading_ui_instance = null
			_loading_in_progress = false
			set_process(false)
