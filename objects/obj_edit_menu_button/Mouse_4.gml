audio_play_sound(snd_button,0,0)
if btn_type == "cancel"{
	instance_destroy(obj_edit_menu)
	obj_player_info_ui.menu_type = 0
}
else if btn_type == "save"{
	with obj_edit_menu{
		event_user(0)
	}
	global.save_data.player.name = global.player_name
	instance_destroy(obj_edit_menu)
	obj_player_info_ui.menu_type = 0
}
else if btn_type == "open_save_folder"{
	var _user_profile = environment_get_variable("LOCALAPPDATA")
	var _target = global.laboratory_manager.file_util.transfer_path_to_windows( _user_profile + "\\FVM_Reborn\\saves")
	var ret = native_open_folder(_target)
	show_debug_message(ret)
}
else if btn_type == "export_save_backup" {
	var _user_profile = environment_get_variable("LOCALAPPDATA")
	var _saves_target = global.laboratory_manager.file_util.transfer_path_to_windows( _user_profile + "\\FVM_Reborn\\saves")
	// var _backup_file_target = global.laboratory_manager.file_util.transfer_path_to_windows( _user_profile + "\\FVM_Reborn\\backups\\tmp.json")
	var ret = native_start_backup(_saves_target)
	show_debug_message("export save backup start: " + string(ret))
}
else if btn_type == "import_save_backup" {
	var _user_profile = environment_get_variable("LOCALAPPDATA")
	var _saves_target = global.laboratory_manager.file_util.transfer_path_to_windows( _user_profile + "\\FVM_Reborn\\saves")
	var _backup_target = global.laboratory_manager.file_util.transfer_path_to_windows( _user_profile + "\\FVM_Reborn\\backups")
	var ret = native_restore_backup(_saves_target, _backup_target)
	show_debug_message("import_save_backup: " + string(ret))
}
