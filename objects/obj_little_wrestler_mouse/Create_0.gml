sprite_index = get_load_sprite("spr_little_wrestler");  //转化额外添加保证触发
event_inherited()

hp = 200
maxhp = 200

move_anim = 12
attack_anim = 6
death_anim = 11

state = ENEMY_STATE.ACTING
sprite_index = get_load_sprite("spr_little_wrestler_throw")
target_type = "air"
target_col = 2
target_row = 0

chspeed = -4
cvspeed = 7
cgravity = -0.2
land_timer = 0