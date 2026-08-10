draw_self()
var card_list = ds_grid_get(global.grid_plants, col, row)
var grid_pos = get_world_position_from_grid(col,row)
if ds_list_size(card_list) > 0 && !has_bubble{
	draw_sprite_ext(spr_drown_effect,floor(timer/5),grid_pos.x+15,grid_pos.y-15,1.8,1.8,0,c_white,1)
}