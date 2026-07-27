/// @function add_to_deck(card_id, shape)
/// @desc 添加指定形态的卡牌到当前出战卡组
function add_to_deck(card_id, shape) {
    // 联机模式禁止 king 小笼包（吸收机制与联机架构冲突）
    if global.network.mode != "offline" && (card_id == "king_long_bao" || card_id == "king_triple_long_bao"){
        return false
    }
    var card_data = deck_get_card_data(card_id, shape);
    if (card_data != noone) {
        // 同时存储卡牌ID和形态信息，以便后续使用
        var deck_entry = ds_map_create();
        deck_entry[? "card_id"] = card_id;
        deck_entry[? "shape"] = shape;
        deck_entry[? "data"] = card_data;
        
        ds_list_add(global.selected_deck, deck_entry);
		return true
    }
	else{
		return false
	}
}