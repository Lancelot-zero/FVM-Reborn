if global.room_battle_front == true{
	exit;
}

if !obj_readyroom_manager.is_submenu_open{
	audio_play_sound(snd_button,0,0)
	clear_deck()
}