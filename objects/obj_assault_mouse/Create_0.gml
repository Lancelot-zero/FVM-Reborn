sprite_index = get_load_sprite("spr_assault_mouse_appear");  //转化额外添加保证触发
 // Inherit the parent event
event_inherited();
hp = 280
maxhp = 280
helmet_hp = 180
helmet_max_hp = 180
death_anim = 8
reversed = false
state = ENEMY_STATE.ACTING
audio_play_sound(snd_enter_water,0,0)
special_ash = true
armor_dropped = false