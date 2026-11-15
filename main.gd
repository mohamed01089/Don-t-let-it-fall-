extends Node2D
# Don't let it fall! - keep the balloon in the air and reach the exit.

const W := 1152.0
const H := 648.0
const GRAVITY := 1500.0
const MOVE_SPEED := 270.0
const JUMP_SPEED := 590.0
const PSIZE := Vector2(28, 44)
const B_GRAVITY := 450.0
const B_RADIUS := 18.0
const BOUNCE := 500.0
const BALLOON_TEX := preload("res://assets/Balloon_Plain.png")
const BALLOON_SCALE := 0.58
const BALLOON_ANCHOR := Vector2(48.5, 43.5) # centre of the balloon body inside the 100x100 image

enum State { PLAYING, DEAD, CLEAR, WON }

const LEVEL_NAMES := ["Level 1 - Morning Hop", "Level 2 - Sunset Stairs", "Level 3 - Starry Night"]

var state := State.PLAYING
var level := 0
var platforms := []
var exit_rect := Rect2()
var stars := []

var ppos := Vector2()
var pvel := Vector2()
var on_ground := false
var facing := 1.0

var bpos := Vector2()
var bvel := Vector2()

var msg := ""
var t := 0.0
var hint_time := 0.0


func _ready() -> void:
	load_level(0)


func load_level(i: int) -> void:
	level = i
	state = State.PLAYING
	msg = ""
	hint_time = 0.0
	platforms = []
	ppos = Vector2(60, 556)
	pvel = Vector2.ZERO
	bpos = Vector2(74, 470)
	bvel = Vector2.ZERO
	match i:
		0: # DAY: gaps and a spiky patch under a low ledge
			platforms = [
				Rect2(0, 600, 380, 48),
				Rect2(520, 600, 632, 48),
				Rect2(700, 430, 140, 20),
			]
			exit_rect = Rect2(1075, 540, 50, 60)
		1: # SUNSET: stepping stones over a bottomless drop
			platforms = [
				Rect2(0, 600, 300, 48),
				Rect2(330, 520, 110, 20),
				Rect2(500, 440, 110, 20),
				Rect2(670, 360, 110, 20),
				Rect2(840, 440, 110, 20),
				Rect2(1010, 470, 142, 20),
			]
			exit_rect = Rect2(1080, 410, 50, 60)
		2: # NIGHT: tiny platforms and wide gaps
			platforms = [
				Rect2(0, 600, 200, 48),
				Rect2(250, 540, 100, 20),
				Rect2(410, 480, 100, 20),
				Rect2(570, 540, 100, 20),
				Rect2(730, 470, 100, 20),
				Rect2(890, 400, 100, 20),
				Rect2(1040, 330, 112, 20),
			]
			exit_rect = Rect2(1080, 270, 50, 60)
			stars = []
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in 70:
				stars.append(Vector3(rng.randf() * W, rng.randf() * 380.0, rng.randf() * 6.0))
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k == KEY_R:
			load_level(0 if state == State.WON else level)
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			match state:
				State.DEAD:
					load_level(level)
				State.CLEAR:
					if level >= 2:
						state = State.WON
					else:
						load_level(level + 1)
				State.WON:
					load_level(0)


func key(a: int, b: int = -1) -> bool:
	return Input.is_physical_key_pressed(a) or (b != -1 and Input.is_physical_key_pressed(b))


func _physics_process(delta: float) -> void:
	t += delta
	if state == State.PLAYING:
		move_player(delta)
		move_balloon(delta)
		check_exit(delta)
	queue_redraw()


func move_player(delta: float) -> void:
	var dir := 0.0
	if key(KEY_A, KEY_LEFT):
		dir -= 1.0
	if key(KEY_D, KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		facing = dir
	pvel.x = move_toward(pvel.x, dir * MOVE_SPEED, 2600.0 * delta)
	pvel.y += GRAVITY * delta
	if (key(KEY_W, KEY_UP) or key(KEY_SPACE)) and on_ground:
		pvel.y = -JUMP_SPEED
		on_ground = false

	# horizontal
	ppos.x += pvel.x * delta
	for p in platforms:
		var r := Rect2(ppos, PSIZE)
		if r.intersects(p):
			if pvel.x > 0.0:
				ppos.x = p.position.x - PSIZE.x
			elif pvel.x < 0.0:
				ppos.x = p.end.x
			pvel.x = 0.0
	ppos.x = clampf(ppos.x, 0.0, W - PSIZE.x)

	# vertical
	ppos.y += pvel.y * delta
	on_ground = false
	for p in platforms:
		var r := Rect2(ppos, PSIZE)
		if r.intersects(p):
			if pvel.y > 0.0:
				ppos.y = p.position.y - PSIZE.y
				on_ground = true
			else:
				ppos.y = p.end.y
			pvel.y = 0.0

	if ppos.y > H + 60.0:
		die("You fell into the void!")


# returns {hit, n, pen} for a circle against a rectangle
func circle_rect(c: Vector2, rad: float, r: Rect2) -> Dictionary:
	var closest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	var d := c - closest
	var dist := d.length()
	if dist >= rad:
		return {"hit": false}
	if dist < 0.001:
		return {"hit": true, "n": Vector2.UP, "pen": rad}
	return {"hit": true, "n": d / dist, "pen": rad - dist}


func move_balloon(delta: float) -> void:
	bvel.y += B_GRAVITY * delta
	bvel.x = clampf(bvel.x, -320.0, 320.0)
	bpos += bvel * delta

	# walls and ceiling: bounce back!
	if bpos.x < B_RADIUS:
		bpos.x = B_RADIUS
		bvel.x = absf(bvel.x) * 0.8
	elif bpos.x > W - B_RADIUS:
		bpos.x = W - B_RADIUS
		bvel.x = -absf(bvel.x) * 0.8
	if bpos.y < B_RADIUS:
		bpos.y = B_RADIUS
		bvel.y = absf(bvel.y) * 0.5

	# platforms: landing on top = the balloon "hit the ground"
	for p in platforms:
		var res := circle_rect(bpos, B_RADIUS, p)
		if res["hit"]:
			var n: Vector2 = res["n"]
			bpos += n * float(res["pen"])
			if n.y < -0.5:
				die("The balloon hit the ground!")
				return
			bvel = bvel.bounce(n) * 0.8

	# the player: head = big bounce, sides = shove
	var pr := Rect2(ppos, PSIZE)
	var res2 := circle_rect(bpos, B_RADIUS, pr)
	if res2["hit"]:
		var n2: Vector2 = res2["n"]
		bpos += n2 * float(res2["pen"])
		if n2.y < -0.4:
			bvel.y = -BOUNCE
			var off := bpos.x - (ppos.x + PSIZE.x * 0.5)
			bvel.x = clampf(off * 8.0 + pvel.x * 0.6, -280.0, 280.0)
		else:
			bvel = bvel.bounce(n2) * 0.9
			bvel.x += pvel.x * 0.5

	if bpos.y > H + 40.0:
		die("The balloon fell away!")


func check_exit(delta: float) -> void:
	if state != State.PLAYING:
		return
	var pr := Rect2(ppos, PSIZE)
	hint_time = maxf(hint_time - delta, 0.0)
	if pr.intersects(exit_rect):
		if bpos.distance_to(exit_rect.get_center()) < 170.0:
			state = State.CLEAR
		else:
			hint_time = 0.2


func die(reason: String) -> void:
	if state == State.PLAYING:
		state = State.DEAD
		msg = reason


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_sky()
	draw_level()
	draw_player()
	draw_balloon()
	draw_hud()


func gradient_rect(top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([top, top, bottom, bottom]))


func draw_sky() -> void:
	match level:
		0:
			gradient_rect(Color(0.30, 0.62, 1.0), Color(0.80, 0.93, 1.0))
			draw_circle(Vector2(980, 100), 46, Color(1, 0.9, 0.2))
			for c in [[150, 110, 1.0], [520, 70, 0.8], [800, 170, 1.2]]:
				var cx: float = fmod(c[0] + t * 8.0 * c[2], W + 200.0) - 100.0
				var cy: float = c[1]
				var s: float = c[2]
				for o in [Vector2(0, 0), Vector2(30, -12), Vector2(60, 0), Vector2(30, 8)]:
					draw_circle(Vector2(cx, cy) + o * s, 28.0 * s, Color(1, 1, 1, 0.9))
		1:
			gradient_rect(Color(0.28, 0.18, 0.45), Color(1.0, 0.56, 0.24))
			draw_circle(Vector2(760, 470), 78, Color(1, 0.9, 0.2))
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 648), Vector2(0, 470), Vector2(170, 380), Vector2(330, 470),
				Vector2(520, 360), Vector2(700, 480), Vector2(900, 400), Vector2(1152, 490),
				Vector2(1152, 648)]), Color(0.22, 0.1, 0.25))
		2:
			gradient_rect(Color(0.02, 0.03, 0.12), Color(0.12, 0.14, 0.32))
			for s in stars:
				var a := 0.5 + 0.5 * sin(t * 2.0 + s.z)
				draw_circle(Vector2(s.x, s.y), 1.4 + a, Color(1, 1, 0.9, 0.4 + 0.6 * a))
			draw_circle(Vector2(190, 110), 46, Color(0.95, 0.95, 0.8))
			draw_circle(Vector2(208, 100), 40, Color(0.05, 0.06, 0.17))


func draw_level() -> void:
	var top_c: Color = [Color(0.35, 0.8, 0.3), Color(0.95, 0.5, 0.25), Color(0.4, 0.55, 0.9)][level]
	var body_c: Color = [Color(0.5, 0.33, 0.18), Color(0.35, 0.16, 0.3), Color(0.16, 0.18, 0.35)][level]
	for p in platforms:
		draw_rect(p, body_c)
		draw_rect(Rect2(p.position, Vector2(p.size.x, 7)), top_c)
	# exit gate
	var glow := 0.5 + 0.5 * sin(t * 4.0)
	draw_rect(exit_rect.grow(6), Color(0.4, 1.0, 0.6, 0.15 + 0.15 * glow))
	draw_rect(exit_rect, Color(0.15, 0.7, 0.4))
	draw_rect(exit_rect.grow(-8), Color(0.7, 1.0, 0.8, 0.8))
	draw_string(ThemeDB.fallback_font, exit_rect.position + Vector2(-8, -8), "EXIT",
		HORIZONTAL_ALIGNMENT_CENTER, exit_rect.size.x + 16, 16, Color(1, 1, 1))


func draw_player() -> void:
	var c := ppos + Vector2(PSIZE.x * 0.5, 0)
	draw_rect(Rect2(ppos + Vector2(0, 22), Vector2(PSIZE.x, 22)), Color(0.2, 0.45, 0.95))
	draw_circle(c + Vector2(0, 12), 13, Color(1.0, 0.82, 0.65))
	draw_circle(c + Vector2(4 * facing, 9), 2.2, Color(0.1, 0.1, 0.1))
	draw_circle(c + Vector2(-3 * facing, 9), 2.2, Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(ppos + Vector2(0, 0), Vector2(PSIZE.x, 6)), Color(0.9, 0.2, 0.2)) # cap


func draw_balloon() -> void:
	if level == 2:
		draw_circle(bpos, 40, Color(1.0, 0.4, 0.5, 0.15))
	var size := BALLOON_TEX.get_size() * BALLOON_SCALE
	draw_texture_rect(BALLOON_TEX, Rect2(bpos - BALLOON_ANCHOR * BALLOON_SCALE, size), false)


func draw_hud() -> void:
	var f := ThemeDB.fallback_font
	var white := Color(1, 1, 1)
	draw_string(f, Vector2(16, 30), "Don't let it fall!  |  " + LEVEL_NAMES[level], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, white)
	if hint_time > 0.0:
		draw_string(f, Vector2(0, 110), "Bring the balloon with you!", HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 0.4))
	match state:
		State.DEAD:
			overlay("YOU LOSE", msg + "  Press Enter or R to retry.", Color(1, 0.35, 0.35))
		State.CLEAR:
			var nxt := "Press Enter for the next level." if level < 2 else "Press Enter to finish."
			overlay("LEVEL CLEAR!", nxt, Color(0.5, 1, 0.6))
		State.WON:
			overlay("YOU WIN!", "You bounced back through all 3 levels! Press Enter to play again.", Color(1, 0.9, 0.3))


func overlay(title: String, sub: String, c: Color) -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	draw_string(f, Vector2(0, 300), title, HORIZONTAL_ALIGNMENT_CENTER, W, 64, c)
	draw_string(f, Vector2(0, 350), sub, HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 1, 1))
