sprite_index = get_load_sprite("spr_glider_mouse_air");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();
hp = 150
maxhp = 150
helmet_hp = 10
move_anim = 8
attack_anim = 4
death_anim = 12
move_speed = 0.72
mouse_id = "glider_mouse"
attack_range = 90

target_type = "air"

state = ENEMY_STATE.APPEAR
sprite_index = get_load_sprite("spr_glider_mouse_air")
special_ash = true
anim_timer = 0