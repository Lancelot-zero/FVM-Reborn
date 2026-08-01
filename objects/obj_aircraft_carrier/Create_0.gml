sprite_index = get_load_sprite("spr_aircraft_carrier");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();
hp = 3510
maxhp = 3510
move_anim = 4
attack_anim = 1
death_anim = 27
move_speed = 0.6
mouse_id = "aircraft_carrier"
attack_range = 90

target_type = "air"

state = ENEMY_STATE.APPEAR
sprite_index = get_load_sprite("spr_aircraft_carrier")
special_ash = true
anim_timer = 0
immune_to_ash = true