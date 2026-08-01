/// @function load_custom_deck(deck_data)
/// @desc 加载自定义卡组（未来从存档/菜单读取）
/// @param {real} deck_index 卡组ID
function load_custom_deck(deck_index) {
    // 清空当前卡组
    ds_list_clear(global.selected_deck);

    // VM 卡槽上限
    var _max_slot = 21;
    if (global._VM_max_slots >= 0) {
        _max_slot = global._VM_max_slots;
    }

    // 添加新卡牌
    var _cards = global.save_data.saved_decks[deck_index].card_id;
    for(var i = 0; i < array_length(_cards); i++) {
        if (ds_list_size(global.selected_deck) >= _max_slot) break;
        var info = get_card_info(_cards[i]);
        if (info != false) {
            add_to_deck(_cards[i], info.shape);
        }
    }
    
    // 重新创建卡槽（需在战斗房间调用）
    if (instance_exists(obj_battle)) {
        // 先删除旧卡槽
        with (obj_card_slot) instance_destroy();
        // 创建新卡槽
        create_battle_slots();
    }
}

function save_to_custom_deck(deck_index,deck_name){
	array_delete(global.save_data.saved_decks[deck_index].card_id,0,21)
	var length = ds_list_size(global.selected_deck)
	for(var i = 0; i < length;i++){
		global.save_data.saved_decks[deck_index].card_id[i] = global.selected_deck[| i][? "card_id"]
	}
	save_file(global.save_slot)
}