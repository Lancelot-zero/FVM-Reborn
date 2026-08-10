if global.is_paused{
	exit
}
if global.debug{
	image_alpha = 0.5
}
var grid_pos = get_world_position_from_grid(col,row)
timer++

has_bubble = false
with obj_card_parent{
	if plant_id == "soda_bubble" && grid_row == other.row && grid_col == other.col{
		on_lava = true
		other.has_bubble = true
	}
}

if timer mod 60 == 0{
    // 使用碰撞检测查找攻击范围内的植物
    with (obj_card_parent) {
		var is_in_front = false
		is_in_front = grid_row == other.row && grid_col == other.col
				
        // 检查是否在攻击范围内
        if (is_in_front && !other.has_bubble) {
            if (plant_type != "coffee" && !invincible && array_get_index(other.ignore_list,plant_id) == -1 && !(plant_id == "player" && hp <= 0.05*max_hp)){
				hp -= 0.05*max_hp
				event_user(2)
			}  
        }
    }
}
