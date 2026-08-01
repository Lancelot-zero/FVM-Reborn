sprite_index = get_load_sprite("spr_landmine_vehicle_mouse");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();

mouse_id = "landmine_vehicle_mouse"

hp = 1220
maxhp = 1220

move_speed = 0.6
move_anim = 6
attack_anim = 12
death_anim = 14
special_ash = true
state = ENEMY_STATE.APPEAR

target_col = -1

cycle = 300
anim_timer = 0
atk_cycle = 1
atk = 2000

sprite_index = get_load_sprite("spr_landmine_vehicle_mouse_move")
