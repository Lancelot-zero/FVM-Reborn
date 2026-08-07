/// @function add_to_deck(card_id, shape)
/// @desc 添加指定形态的卡牌到当前出战卡组
function add_to_deck(card_id, shape) {
    if !is_undefined(global.banned_cards_online[? card_id]){
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