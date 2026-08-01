sprite_index = get_load_sprite("spr_kamikaze_glider_mouse_air");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();
hp = 2340
maxhp = 2340
helmet_hp = 1
move_anim = 1
attack_anim = 1
death_anim = 1
move_speed = 0.6
mouse_id = "kamikaze_glider_mouse"
attack_range = 90

target_type = "air"

state = ENEMY_STATE.APPEAR
sprite_index = get_load_sprite("spr_kamikaze_glider_mouse_air")
special_ash = true
anim_timer = 0
immune_to_ash = true