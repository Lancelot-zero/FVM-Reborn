sprite_index = get_load_sprite("spr_irritable_jack_head_skill_3");  //转化额外添加保证触发
// Inherit the parent event
event_inherited();

timer = 0
hp = 1800
maxhp = 1800
state = "appear"
anim_wait = 90
special_ash = true
mouse_id = "irritable_jack_rock"
move_speed = 1

prev_spr = get_load_sprite("spr_irritable_jack_head_skill_3")
next_spr = get_load_sprite("spr_irritable_jack_head_skill_4")

immune_to_ash = true