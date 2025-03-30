extends Node3D
"""
Water ripple effect shader (无随机雨滴版本, 编辑器里直接选定目标船只)
当选定的 "target_ship" 进入该 Area3D 范围时，根据其位置产生波纹。
适用于 Godot 4.3
"""

@export var target_ship: Node3D     # 在编辑器里拖拽“你的船”到这里即可
@export var boat_wave_size: float = 5.0                  # 船产生波纹的强度
@export var texture_size: Vector2i = Vector2i(512, 512)  # 水波纹理大小
@export_range(1.0, 10.0, 0.1) var damp: float = 1.0      # 衰减系数(越大波纹越易被抑制)

var texture: Texture2DRD
var next_texture: int = 0

# 该向量存储水波参数:
# x, y = 船体映射到纹理上的像素位置
# z    = 波纹半径大小(强度)
# w    = 是否需要产生波纹 (1 = 产生, 0 = 不产生)
var add_wave_point: Vector4 = Vector4(0, 0, 0, 0)

# 记录当前进入 Area3D 的“目标船”节点
var boat_body: Node = null

# --- 渲染相关资源 ---
var rd: RenderingDevice
var shader: RID
var pipeline: RID
# 我们用 3 个纹理轮流计算：当前帧、上一帧、上上一帧
var texture_rds: Array[RID] = [RID(), RID(), RID()]
var texture_sets: Array[RID] = [RID(), RID(), RID()]


func _ready() -> void:
	# 连接 Area3D 信号，当船进入/离开时触发


	# 在渲染线程初始化计算着色器及纹理资源
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(texture_size))

	# 从水面材质中拿到贴图 RID 并设置参数
	var material: ShaderMaterial = $MeshInstance3D.material_override
	if material:
		material.set_shader_parameter("effect_texture_size", texture_size)
		texture = material.get_shader_parameter("effect_texture")


func _exit_tree() -> void:
	# 清理相关资源
	if texture:
		texture.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_free_compute_resources)


func _on_body_entered(body: Node) -> void:
	# 如果这个 body 就是我们在编辑器里指定的 "target_ship"，
	# 则记录为当前的 boat_body
	if body == target_ship:
		boat_body = body


func _on_body_exited(body: Node) -> void:
	# 若离开的body就是我们的目标船，则清除引用
	if body == boat_body:
		boat_body = null


func _process(delta: float) -> void:
	# 如果当前 "船" 在水面范围内
	if boat_body:
		# 计算船在当前Area3D本地坐标系下的位置
		var local_pos: Vector3 = global_transform.affine_inverse() * boat_body.global_transform.origin

		# 将本地坐标映射到 0~texture_size 的范围
		# 这里假设水面中心大约对齐 local_pos.xz = [-2.5, 2.5] => [0, texture_size]
		# 你可根据实际水面大小调整除数及 clamp 范围
		add_wave_point.x = clamp(local_pos.x / 5.0, -0.5, 0.5) * float(texture_size.x) + 0.5 * float(texture_size.x)
		add_wave_point.y = clamp(local_pos.z / 5.0, -0.5, 0.5) * float(texture_size.y) + 0.5 * float(texture_size.y)

		# w=1 表示需要产生波纹, z=波纹强度(半径)
		add_wave_point.w = 1.0
		add_wave_point.z = boat_wave_size
	else:
		# 如果指定的 "target_ship" 不在范围内，就不产生任何波纹
		add_wave_point.w = 0.0
		add_wave_point.z = 0.0

	# 换下一帧的贴图
	next_texture = (next_texture + 1) % 3
	if texture:
		texture.texture_rd_rid = texture_rds[next_texture]

	# 把水波信息推给渲染线程去跑
	RenderingServer.call_on_render_thread(
		_render_process.bind(next_texture, add_wave_point, texture_size, damp)
	)


###############################################################################
# 以下函数在渲染线程执行: 负责创建/管理计算着色器、纹理，以及执行波纹计算
###############################################################################
func _initialize_compute_code(init_with_texture_size: Vector2i) -> void:
	rd = RenderingServer.get_rendering_device()

	# 加载 compute shader
	var shader_file := load("res://water_plane/water_compute.glsl")  # 你的 compute shader 路径
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	# 创建 3 张纹理来回切换
	var tf: RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = init_with_texture_size.x
	tf.height = init_with_texture_size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)

	for i in 3:
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])
		rd.texture_clear(texture_rds[i], Color(0,0,0,0), 0, 1, 0, 1)
		texture_sets[i] = _create_uniform_set(texture_rds[i])


func _create_uniform_set(texture_rd: RID) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, 0)


func _render_process(
	with_next_texture: int,
	wave_point: Vector4,
	tex_size: Vector2i,
	p_damp: float
) -> void:
	# 用 push constant 传入水波数据
	var push_constant := PackedFloat32Array()
	push_constant.push_back(wave_point.x)
	push_constant.push_back(wave_point.y)
	push_constant.push_back(wave_point.z)
	push_constant.push_back(wave_point.w)

	push_constant.push_back(tex_size.x)
	push_constant.push_back(tex_size.y)
	push_constant.push_back(p_damp)
	push_constant.push_back(0.0)

	# 计算调度组大小(使用 8x8 分组)
	var x_groups := (tex_size.x - 1) / 8 + 1
	var y_groups := (tex_size.y - 1) / 8 + 1

	var next_set := texture_sets[with_next_texture]
	var current_set := texture_sets[(with_next_texture - 1) % 3]
	var previous_set := texture_sets[(with_next_texture - 2) % 3]

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, previous_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()


func _free_compute_resources() -> void:
	for i in 3:
		if texture_rds[i]:
			rd.free_rid(texture_rds[i])

	if shader:
		rd.free_rid(shader)
