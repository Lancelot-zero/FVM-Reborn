sprite_index = get_load_sprite("spr_machine_flag_mouse_air");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();
hp = 1600
maxhp = 1600
helmet_hp = 1200
move_anim = 9
attack_anim = 5
death_anim = 18
move_speed = 0.72
mouse_id = "machine_flag_mouse"
attack_range = 90

target_type = "air"

state = ENEMY_STATE.APPEAR
sprite_index = get_load_sprite("spr_machine_flag_mouse_air")
special_ash = true
anim_timer = 0
immune_to_ash = true