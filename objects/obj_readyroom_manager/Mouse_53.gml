if hover_card_index != -1 && !is_submenu_open{
	if ds_list_size(global.selected_deck) < global.save_data.unlocked_items.max_slot{
		audio_play_sound(snd_button,0,0)
		var card_id = global.player_deck[| hover_card_index*2];
		// 联机模式禁止选择 king 小笼包（吸收机制与联机架构冲突）
		if global.network.mode != "offline" && (card_id == "king_long_bao" || card_id == "king_triple_long_bao"){
			show_notice("联机模式暂不支持此卡片", 60)
		}else{
			add_to_deck(card_id,get_card_info_simple(card_id).shape)
		}
	}
}
if hover_slot_index != -1 && !is_submenu_open{
	audio_play_sound(snd_button,0,0)
	ds_list_delete(global.selected_deck,hover_slot_index)
}
if(mouse_x > 785 && mouse_x < 1546 && mouse_y > 762 && mouse_y < 980) && !is_submenu_open{
	audio_play_sound(snd_button,0,0)
	var inst = instance_create_depth(0,0,-500,obj_level_preview)
	inst.enemy_type_list = enemy_type_list
	inst.boss_type_list = boss_type_list
}