sprite_index = get_load_sprite("spr_ice_residue_disappear");  //转化额外添加保证触发
// Inherit the parent event
event_inherited();

mouse_id = "ice_residue"
jump_times = 0
state = BOSS_STATE.APPEAR
hp = 12000
maxhp = 12000
immune_to_ash = true
wait_time = 0
cave = noone
sprite_index = get_load_sprite("spr_ice_residue_appear")
is_boss = true
step_ready = false;	frame_count = 0;
skill_count = 0

hpbar_inst = instance_create_depth(450,1040,-900,obj_boss_hpbar)
hpbar_inst.target_boss = id
hpbar_inst.boss_id = mouse_id

if obj_battle.boss_count > 0{
	hpbar_inst.y -= 40
}

shape = "ice"
spr_list = [get_load_sprite("spr_ice_residue_appear"),get_load_sprite("spr_ice_residue_skill_1_ready"),get_load_sprite("spr_ice_residue_skill_1"),get_load_sprite("spr_ice_residue_skill_2"),get_load_sprite("spr_ice_residue_disappear"),get_load_sprite("spr_ice_residue_death")]