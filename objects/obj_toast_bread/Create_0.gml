sprite_index = get_load_sprite("spr_toast_bread");  //转化额外添加保证触发
event_inherited();  // 继承父对象属性
plant_id = "toast_bread"; 
// 设置对象类型和精灵
obj_type = object_index;
event_user(0)

// ========== 特定属性默认值 ==========
attack_anim = 0;
plant_type = "normal"