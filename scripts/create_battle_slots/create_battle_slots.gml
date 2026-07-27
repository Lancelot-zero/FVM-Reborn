/// @function create_battle_slots()
/// @desc 根据当前卡组创建战斗卡槽
function create_battle_slots() {
    var start_x = 535;
    var y_pos = 90;
    var x_spacing = 90;
	var y_spacing = 118;
    
    for(var i = 0; i < ds_list_size(global.selected_deck); i++) {
        var deck_entry = global.selected_deck[| i];
        var card_data = deck_entry[? "data"];
        var inst = noone
		if i <= 14{
			inst = instance_create_depth(
            start_x + i * x_spacing, 
            y_pos, 
            -5, 
            obj_card_slot
        );
		}
		else{
			inst = instance_create_depth(
            start_x + 14 * x_spacing, 
            y_pos+(i-14)*y_spacing, 
            -5, 
            obj_card_slot
        )
		}
        
        inst.cost = card_data[? "cost"];
        inst.cooldown = card_data[? "cooldown"];
        // 联机魔塔：冷却+50%
        if global.network.mode != "offline" && global.map_id == "tower_cake"{
            inst.cooldown = ceil(inst.cooldown * 1.5);
        }
        inst.card_obj = card_data[? "obj"]; 
        inst.card_spr = card_data[? "sprite"];
		inst.place_preview = card_data[? "place_preview"]
        inst.description = card_data[? "description"];
        inst.slot_index = i + 1;
		inst.card_id = deck_entry[? "card_id"];
        inst.shape = deck_entry[? "shape"]; // 存储形态信息
		inst.depth = -2000
		//show_debug_message("植物卡槽已生成，id：" + inst.card_id)
    }
}