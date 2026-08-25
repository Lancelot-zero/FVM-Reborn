if global.is_paused{
	exit
}
event_inherited(); 

if shape < 1{
	drown_timer ++
	if drown_timer mod 60 == 0{
		//0转检测是否有气泡和海水
		var has_bubble = false
		var has_seawater = false
		
		var card_list = ds_grid_get(global.grid_plants, grid_col,  grid_row);
		if(ds_exists(card_list,ds_type_list)){
		    for(var i=0;i<ds_list_size(card_list);i++){
		        var it = card_list[|i];
				if(instance_exists(it))
		        {
		            if(variable_instance_exists(it, "plant_id") && it.plant_id == "soda_bubble")
		                has_bubble = true;
		        }
		    }
		}
		/*
		with obj_card_parent{
			if plant_id == "soda_bubble" && grid_col == other.grid_col && grid_row == other.grid_row{
				has_bubble = true
			}
		}*/
		with obj_seawater{
			if col == other.grid_col && row == other.grid_row{
				has_seawater = true
			}
		}
		if !has_bubble && !has_seawater{
			hp -= 0.05*max_hp
			event_user(2)
		}
	}
}

if is_frozen || state == CARD_STATE.SLEEP{
	exit
}
var current_flash_speed = flash_speed
if is_slowdown{
	current_flash_speed *= 2
}
//检测自身右方是否有敌人
var has_enemy = false
with(obj_enemy_parent){
	if ((grid_row == other.grid_row || grid_col >= other.grid_col && grid_col <= (global.grid_cols + 1))&& can_target_on(other.target_type,target_type)){
		has_enemy = true
		break
	}
}

//攻击逻辑
if (has_enemy) {
    if (attack_timer <= cycle - attack_anim * current_flash_speed) {
        attack_timer++;
    } else if (attack_timer <= cycle) {
        attack_timer++;
        state = CARD_STATE.ATTACK;
    } else {
        attack_timer = 0;
        state = CARD_STATE.IDLE;
    }
	if shape < 2{
		if attack_timer == cycle - 8*current_flash_speed{
			event_user(1)
			audio_play_sound(snd_shot,0,0)
		}
	}
	else{
		if attack_timer == cycle - 5*current_flash_speed{
			event_user(1)
			audio_play_sound(snd_shot,0,0)
		}
		if attack_timer == cycle - 2*current_flash_speed{
			event_user(1)
			audio_play_sound(snd_shot,0,0)
		}
	}
} else {
    // 没有符合条件的敌人，重置状态
    attack_timer = 0;
    state = CARD_STATE.IDLE;
}

