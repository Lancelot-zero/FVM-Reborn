var target = find_priority_enemy()
if target != noone{
	var inst = instance_create_depth(x,y-90,depth-1,obj_currylobstercannon_bullet)
	inst.target_col = target.grid_col
	inst.target_row = target.grid_row
	inst.target_enemy = target
	inst.damage = atk
	inst.b_shape = shape

	if shape == 1{
		inst.sprite_index = spr_curry_lobster_cannon_bullet_1
	}
	if shape == 2{
		inst.sprite_index = spr_curry_lobster_cannon_bullet_2
	}
}