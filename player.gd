extends CharacterBody3D

const SPEED := 3.5
const RUN_SPEED := 6.5
const JUMP_VELOCITY := 5.0
const ROT_SPEED := 10.0
const MOUSE_SENS := 0.005

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = _find_anim_player(model)
@onready var cam_pivot: Node3D = $CamPivot
@onready var spring: SpringArm3D = $CamPivot/SpringArm3D

const ANIM_SOURCES := {
	"Idle":   "res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Confused_Scratch_withSkin.glb",
	"Walk":   "res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Walking_withSkin.glb",
	"Run":    "res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Running_withSkin.glb",
	"Pickup": "res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Male_Bend_Over_Pick_Up_withSkin.glb",
	"Shrug":  "res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Shrug_withSkin.glb",
	"Jump":"res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Regular_Jump_withSkin.glb",
	"Jump_Run":"res://Meshy_AI_Red_Shirt_Wolf_of_the_biped_Animation_Jump_Run_withSkin.glb",
}

var jumping_anim := "Jump"

var _current_anim := ""
# Mientras _anim_lock > 0 se mantiene la animación de acción (agarrar).
var _anim_lock := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_import_animations()
	_align_model_to_feet()
	_play("Idle")

func _align_model_to_feet() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var aabb := AABB()
	var first := true
	for n in _all_descendants(model):
		if n is VisualInstance3D:
			var vi := n as VisualInstance3D
			var a: AABB = vi.global_transform * vi.get_aabb()
			if first:
				aabb = a
				first = false
			else:
				aabb = aabb.merge(a)
	if first:
		print("[Player] No se encontró VisualInstance3D dentro de Model")
		return
	var lowest_world_y := aabb.position.y
	var highest_world_y := aabb.position.y + aabb.size.y
	var feet_world_y := global_position.y
	var delta := feet_world_y - lowest_world_y
	model.position.y += delta
	print("[Player] AABB modelo (mundo): min Y=", lowest_world_y, " max Y=", highest_world_y, " size=", aabb.size)
	print("[Player] Pies del body Y=", feet_world_y, " -> offset Y aplicado al Model=", delta, " (nueva model.position=", model.position, ")")

func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_descendants(c))
	return out

func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

func _import_animations() -> void:
	if anim == null:
		push_warning("No AnimationPlayer found on Model")
		return
	var lib := AnimationLibrary.new()
	for name in ANIM_SOURCES.keys():
		var path: String = ANIM_SOURCES[name]
		var scn: PackedScene = load(path)
		if scn == null:
			continue
		var inst := scn.instantiate()
		var src_anim := _find_anim_player(inst)
		if src_anim and src_anim.get_animation_list().size() > 0:
			var first_name: String = src_anim.get_animation_list()[0]
			var a: Animation = src_anim.get_animation(first_name).duplicate()
			if name == "Idle" or name == "Walk" or name == "Run":
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(name, a)
		inst.queue_free()
	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", lib)

func _play(name: String) -> void:
	if anim == null or _current_anim == name:
		return
	if not anim.has_animation(name):
		return
	_current_anim = name
	anim.play(name, 0.15)

# Devuelve el PickupSystem hijo.
func get_pickup_system() -> PickupSystem:
	for c in get_children():
		if c is PickupSystem:
			return c
	return null

const PICKUP_SPEED := 3.0

func reproducir_pickup() -> void:
	if anim == null or not anim.has_animation("Pickup"):
		return
	_current_anim = "Pickup"
	anim.play("Pickup", 0.1, PICKUP_SPEED)
	_anim_lock = anim.get_animation("Pickup").length / PICKUP_SPEED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_pivot.rotate_y(-event.relative.x * MOUSE_SENS)
		spring.rotate_x(-event.relative.y * MOUSE_SENS)
		spring.rotation.x = clamp(spring.rotation.x, -1.2, 0.4)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var running := Input.is_action_pressed("sprint")
	var speed := RUN_SPEED if running else SPEED

	var basis := cam_pivot.global_transform.basis
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := (right * input_dir.x + fwd * input_dir.y).normalized()

	if not is_on_floor():
		velocity.y -= 9.8 * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		if running and dir.length() > 0.0:
			jumping_anim = "Jump_Run"
		else:
			jumping_anim = "Jump"

		velocity.y = JUMP_VELOCITY

	if dir.length() > 0.0:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, ROT_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()

	# Mientras dura la animación de agarrar, no la pisa la locomoción.
	if _anim_lock > 0.0:
		_anim_lock -= delta
		return

	if not is_on_floor():
		_play(jumping_anim)
	elif dir.length() > 0.0:
		_play("Run" if running else "Walk")
	else:
		_play("Idle")
