sprite_index = get_load_sprite("spr_magician_mouse");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();

mouse_id = "magician_mouse"

hp = 420
maxhp = 420

move_speed = 0.6
move_anim = 6
attack_anim = 23
death_anim = 14
special_ash = true
state = ENEMY_STATE.APPEAR

target_col = -1

cycle = 480
anim_timer = 0
atk_cycle = 1
atk = 2000

sprite_index = get_load_sprite("spr_magician_mouse")
