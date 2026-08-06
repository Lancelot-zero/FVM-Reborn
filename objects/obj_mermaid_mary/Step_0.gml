if global.is_paused{
	exit
}

if flash_value > 0 {
	flash_value -= 10
}

if !appear{
	var enemy_row = irandom_range(0,global.grid_rows-1)
	var enemy_pos = {}
	enemy_pos = get_world_position_from_grid(10,3)
	x = enemy_pos.x - 90
	y = enemy_pos.y + 30
	image_alpha = 1
	timer = 0
	state = BOSS_STATE.APPEAR
	appear = true
}

// 死亡处理
if (hp <= 0 && state != BOSS_STATE.DEATH) {
	global.save_data.player.gold += 1000
    timer = 0;
    state = BOSS_STATE.DEATH;
    target_plant = noone;  // 清除攻击目标
	with obj_battle{
		if boss_count <= 1 && current_wave >= total_wave - 1{
			timer_pause = true
		}
	}
}

switch state{
	case BOSS_STATE.IDLE:
		sprite_index = spr_mermaid_mary_idle
		if hp > maxhp * hurt_rate{
			image_index = floor(timer/5) mod 14
		}
		else{
			image_index = floor(timer/5) mod 14 + 14
		}
		if timer >= wait_time{
			timer = 0
			state = BOSS_STATE.DISAPPEAR
		}
		break
		
	case BOSS_STATE.APPEAR:
		sprite_index = spr_mermaid_mary_idle
		if hp > maxhp * hurt_rate{
			image_index = floor(timer/5) mod 14
		}
		else{
			image_index = floor(timer/5) mod 14 + 14
		}
		if timer == 14 * 5 - 1{
			timer = 0
			if skill_count == 0{
				state = BOSS_STATE.SKILL1
			}
			else if skill_count == 1{
				state = BOSS_STATE.SKILL2
			}
			else if skill_count == 2{
				state = BOSS_STATE.SKILL3
			}
			skill_count ++
			if skill_count >= 3{
				skill_count = 0
			}
			break
		}
		break
	
	case BOSS_STATE.SKILL1:
		sprite_index = spr_mermaid_mary_skill_1
		if hp > maxhp * hurt_rate{
			image_index = floor(timer/5) mod 30
		}
		else{
			image_index = floor(timer/5) mod 30 + 30
		}
		
		if timer == 18 * 5 - 1{
			for(var i = 0 ; i < global.grid_rows ; i++){
				var wave_pos = get_world_position_from_grid(8,i)
				var wave_inst = instance_create_depth(wave_pos.x+10,wave_pos.y+15,-800,obj_mermaid_mary_wave)
				wave_inst.grid_row = i
			}
		}
		
		if timer >= 30 * 5 - 1{
			jump_times = 0
			timer = 0
			state = BOSS_STATE.IDLE
		}
		break
		
	case BOSS_STATE.SKILL2:
		sprite_index = spr_mermaid_mary_skill_2
		if hp > maxhp * hurt_rate{
			image_index = floor(timer /5) mod 30
		}
		else{
			image_index = floor(timer /5) mod 30 + 30
		}
		
		if timer >= 30*5-1{
			jump_times = 0
			timer = 0
			state = BOSS_STATE.IDLE
		}
		break
		
	case BOSS_STATE.SKILL3:
		
		sprite_index = spr_mermaid_mary_skill_3
		if hp > maxhp * hurt_rate{
			image_index = floor(timer /5) mod 30
		}
		else{
			image_index = floor(timer /5) mod 30 + 30
		}
		
		if timer >= 30*5-1{
			jump_times = 0
			timer = 0
			state = BOSS_STATE.IDLE
		}
		break
		
	case BOSS_STATE.DISAPPEAR:
		sprite_index = spr_mermaid_mary_dash
		if hp > maxhp * hurt_rate{
			image_index = floor(timer/5) mod 6
		}
		else{
			image_index = floor(timer/5) mod 6 + 6
		}
		if timer == 1{
			var enemy_row = irandom_range(0,global.grid_rows-1)
			var enemy_pos = {}
			if skill_count == 0{
				enemy_pos = get_world_position_from_grid(10,3)
			}
			else if skill_count == 2{
				enemy_pos = get_world_position_from_grid(10,enemy_row)
			}
			else if skill_count == 1{
				enemy_row = irandom_range(1,global.grid_rows-2)
				enemy_pos = get_world_position_from_grid(-1,enemy_row)
			}
			x_move_speed = (enemy_pos.x - 90 - x)/180
			y_move_speed = (enemy_pos.y + 30 - y)/180
		}
		if timer >= 1 && timer <= 180{
			x += x_move_speed
			y += y_move_speed
		}
		if timer == 180{
			if skill_count == 1{
				image_xscale = -1.8
			}
			else{
				image_xscale = 1.8
			}
			timer = 0
			state = BOSS_STATE.APPEAR
		}
		break
	
	case BOSS_STATE.DEATH:
		sprite_index = spr_mermaid_mary_death
		image_index = floor(timer/5) mod image_number
		if timer >= image_number * 5{
			image_alpha -= 0.1
			image_index = image_number - 1
		}
		break
}


timer ++


// 透明度处理
if (image_alpha <= 0 && state == BOSS_STATE.DEATH) {
    instance_destroy();
}


var zombie_grid = get_grid_position_from_world(x, y);

// 更新僵尸的网格位置和深度

var base_depth = -10 - (zombie_grid.row * 45) - (zombie_grid.col * 5);
depth = base_depth - 4.5; // 僵尸比植物稍微靠后一点（在护罩外侧和咖啡豆之间）

// 保持网格位置更新

grid_col = zombie_grid.col;
grid_row = zombie_grid.row;

