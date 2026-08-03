// ============================================================
// VM — 内存型虚拟机（无寄存器，全内存寻址）
// 内存单元: { type, value }   type: 0=int 1=float 2=字符串池索引
// ============================================================

// 操作码 (u8)
#macro VM_OP_ASSIGN  1    // dst(u32) type(u8) value(s32)
#macro VM_OP_COPY    2    // dst(u32) src(u32)
#macro VM_OP_ADD     3    // dst(u32) a(u32) b(u32)
#macro VM_OP_SUB     4
#macro VM_OP_MUL     5
#macro VM_OP_DIV     6
#macro VM_OP_MOD     7
#macro VM_OP_EQ      8    // dst = (a == b) ? 1 : 0 (type=int)
#macro VM_OP_NEQ     9
#macro VM_OP_GT      10
#macro VM_OP_GTE     11
#macro VM_OP_LT      12
#macro VM_OP_LTE     13
#macro VM_OP_CALL    14   // func_id(u16) arg_count(u8) dst(s32) [addr(s32)*]
#macro VM_OP_IF      15   // cond_addr(u32) true_ip(s32) false_ip(s32)
#macro VM_OP_JMP     16   // ip(s32)
#macro VM_OP_HALT    17

// 内存类型 (u8)
#macro VM_TYPE_INT    0
#macro VM_TYPE_FLOAT  1
#macro VM_TYPE_STRING 2

// CALL dst 特殊值
#macro VM_DST_VOID    -1

/// @function VM_Create(mem_size)
function VM_Create(mem_size = 32768) {
    var vm = {
        mem_type: array_create(mem_size, VM_TYPE_INT),
        mem_val:  array_create(mem_size, 0),
        functions: [],
        func_ret_types: [],
        strings: []
    };
    return vm;
}

/// @function VM_RegisterFunction(vm, script_func, ret_type)
/// @param ret_type 返回类型，默认 VM_TYPE_INT
/// @return 函数ID (u16)
function VM_RegisterFunction(vm, script_func, ret_type = VM_TYPE_INT) {
    var func_id = array_length(vm.functions);
    array_push(vm.functions, script_func);
    array_push(vm.func_ret_types, ret_type);
    return func_id;
}


// ============================================================
// 游戏 API 函数
// ============================================================
function VM_BanCard(card_id_addr) {
    var card_id = vm_read_mem(global.__vm, card_id_addr);
    global.banned_cards_online[? card_id] = true;
}
function VM_SetCardLevelCap(level_addr) {
    global._VM_card_level_cap = vm_read_mem(global.__vm, level_addr);
}
function VM_SetMaxSlots(n_addr) {
    global._VM_max_slots = vm_read_mem(global.__vm, n_addr);
}
function VM_ShellPrint(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p) {
    var _addrs = [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p];
    var _msg = "";
    for (var _n = 0; _n < 16; _n++) {
        if (!is_undefined(_addrs[_n])) _msg += string(vm_read_mem(global.__vm, _addrs[_n]));
    }
    shell_print(_msg);
}
function VM_ShowNotice(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p) {
    var _addrs = [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p];
    var _msg = "";
    for (var _n = 0; _n < 16; _n++) {
        if (!is_undefined(_addrs[_n])) _msg += string(vm_read_mem(global.__vm, _addrs[_n]));
    }
    show_notice(_msg, 120);
}
function VM_CreatePlatform(col_addr, row_addr, width_addr, length_addr, axis_addr, distance_addr, idle_addr, spr_addr) {
    var col = vm_read_mem(global.__vm, col_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    var width = vm_read_mem(global.__vm, width_addr);
    var length = vm_read_mem(global.__vm, length_addr);
    var axis = vm_read_mem(global.__vm, axis_addr);
    var distance = vm_read_mem(global.__vm, distance_addr);
    var idle = vm_read_mem(global.__vm, idle_addr);
    var spr = vm_read_mem(global.__vm, spr_addr);
    if (global.network.mode == "client") return -1;
    var _pos = get_world_position_from_grid(col, row);
    var _plat = instance_create_depth(
        _pos.x - global.grid_cell_size_x / 2,
        _pos.y - global.grid_cell_size_y / 2 - 35,
        800, obj_platform
    );
    _plat.start_col = col;
    _plat.start_row = row;
    _plat.width = width;
    _plat.length = length;
    _plat.move_axis = (axis == 0) ? "y" : "x";
    _plat.move_distance = distance;
    _plat.initial_offset = 0;
    _plat.initial_idle_duration = 0;
    _plat.boundary_idle_duration = idle;
    if (!is_undefined(spr) && spr != "") {
        _plat.sprite_index = _VM_LoadSpriteFile(spr);
    }
    // 网络同步
    if (global.network.mode == "server") {
        add_net_id(_plat.id);
        // 广播平台创建给所有客户端
        var _nid = global.network.map_instance_id_net_id[? _plat.id];
        var _props = {};
        // 采集 _sync_keys 白名单中的属性
        for (var _k = 0; _k < array_length(global._sync_keys); _k++) {
            var _key = global._sync_keys[_k];
            if (variable_instance_exists(_plat.id, _key)) {
                _props[$ _key] = variable_instance_get(_plat.id, _key);
            }
        }
        // sprite_index 转为字符串名，跨客户端兼容懒加载
        if (variable_struct_exists(_props, "sprite_index")) {
            var _sid = _props[$ "sprite_index"];
            if (ds_map_exists(global._pid_reverse, _sid)) {
                _props[$ "sprite_index"] = global._pid_reverse[? _sid];
            } else {
                _props[$ "sprite_index"] = sprite_get_name(_sid);
            }
        }
        var _action = [{
            op: "spawn",
            obj: "obj_platform",
            x: _plat.x,
            y: _plat.y,
            depth: _plat.depth,
            net_id: _nid,
            props: _props
        }];
        var _json = json_stringify(_action);
        var _cl = global.network.connected_clients;
        for (var _i = 0; _i < array_length(_cl); _i++) {
            send_message(_cl[_i], MSG_EVENT_ACTIONS, _json);
        }
    }
    return real(_plat.id);
}

/// @function _VM_LoadSpriteFile(name)
function _VM_LoadSpriteFile(name) {
    if (variable_global_exists("network") && global.network.mode == "client") {
        return file_cache_load_sprite(name, -1, "", "");
    }
    var _paths = [];
    if (variable_global_exists("_file_cache_json_path")) {
        array_push(_paths, laboratory_resolve_datafile_path(name, global._file_cache_json_path));
    }
    array_push(_paths, "laboratory/" + name);
    array_push(_paths, name);
    for (var _i = 0; _i < array_length(_paths); _i++) {
        if (file_exists(_paths[_i])) {
            var _spr = sprite_add(_paths[_i], 1, false, false, 0, 0);
            if (_spr != -1) {
                ds_map_add(global._pid_reverse, _spr, name);
                ds_map_add(global._sprite_cache, name, _spr);
                ds_map_add(global._sprite_state, name, full_load);
                return _spr;
            }
        }
    }
    return -1;
}

/// @function VM_LoadSprite(name_addr)
/// @return sprite index
function VM_LoadSprite(name_addr) {
    var _pool_idx = global.__vm.mem_val[name_addr];
    array_push(global._VM_loaded_sprite_indices, _pool_idx);
    var name = vm_read_mem(global.__vm, name_addr);
    return _VM_LoadSpriteFile(name);
}

/// @function VM_GetLoadedSpriteName(index)
/// @param index  加载序号（0 开始）
/// @return 字符串池索引，越界返回 -1
function VM_GetLoadedSpriteName(index_addr) {
    var index = vm_read_mem(global.__vm, index_addr);
    if (index < 0 || index >= array_length(global._VM_loaded_sprite_indices)) return -1;
    return global._VM_loaded_sprite_indices[index];
}

/// @function VM_SetDrawSlot(slot, sprite, x, y, alpha)
/// @param slot   槽位索引 0~7
/// @param sprite  贴图名(string)或精灵ID(int)，空/""/-1/noone 时清除
/// @param x      X 坐标
/// @param y      Y 坐标
/// @param alpha  透明度 0~1
function VM_SetDrawSlot(slot_addr, sprite_addr, x_addr, y_addr, alpha_addr) {
    var slot = vm_read_mem(global.__vm, slot_addr);
    var sprite = vm_read_mem(global.__vm, sprite_addr);
    var _x = vm_read_mem(global.__vm, x_addr);
    var _y = vm_read_mem(global.__vm, y_addr);
    var alpha = vm_read_mem(global.__vm, alpha_addr);
    if (slot < 0 || slot >= 8) return;
    if (sprite == "" || sprite == -1 || sprite == noone) {
        global.map_draw_slots[slot].sprite = noone;
        global.map_draw_slots[slot].x = 0;
        global.map_draw_slots[slot].y = 0;
        global.map_draw_slots[slot].alpha = 1;
        return;
    }
    var _spr;
    if (is_real(sprite)) {
        _spr = sprite;
    } else {
        _spr = _VM_LoadSpriteFile(sprite);
    }
    global.map_draw_slots[slot].sprite = _spr;
    global.map_draw_slots[slot].x = _x;
    global.map_draw_slots[slot].y = _y;
    global.map_draw_slots[slot].alpha = alpha;
}

/// @function VM_SetMapBackground(name, step)
/// @param name  贴图名（内置精灵名或外部文件名）
/// @param step  渐变步长，0~1 浮点数
function VM_SetMapBackground(name_addr, step_addr) {
    var name = vm_read_mem(global.__vm, name_addr);
    var step = vm_read_mem(global.__vm, step_addr);
    var _spr = -1;
    if (ds_map_exists(global._sprite_cache, name)) {
        _spr = global._sprite_cache[? name];
    } else {
        _spr = get_load_sprite(name);
    }
    global.map_sprite_target = _spr;
    global.map_fade_alpha = 0;
    if (step > 0) global.map_fade_step = step;
}

/// @function VM_SetTerrain(col, row, type)
/// @param col  列，-1=所有列
/// @param row  行，-1=所有行
/// @param type 地形: "normal"/"water"/"obstacle"
function VM_SetTerrain(col_addr, row_addr, type_addr) {
    var col = vm_read_mem(global.__vm, col_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    var type = vm_read_mem(global.__vm, type_addr);
    var _c1 = (col == -1) ? 0 : col;
    var _c2 = (col == -1) ? global.grid_cols - 1 : col;
    var _r1 = (row == -1) ? 0 : row;
    var _r2 = (row == -1) ? global.grid_rows - 1 : row;
    for (var _r = _r1; _r <= _r2; _r++) {
        for (var _c = _c1; _c <= _c2; _c++) {
            global.grid_terrains[_r][_c].type = type;
            if (type != "water") { global.row_feature[_r] = "land"; }
        }
    }
}

/// @function VM_GetFlame()
/// @return 当前火苗数量
function VM_GetFlame() {
    return global.flame;
}

/// @function VM_ClearPlants(col, row)
/// @param col  列，-1=所有列
/// @param row  行，-1=所有行
function VM_ClearPlants(col_addr, row_addr) {
    var col = vm_read_mem(global.__vm, col_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    var _c1 = (col == -1) ? 0 : col;
    var _c2 = (col == -1) ? global.grid_cols - 1 : col;
    var _r1 = (row == -1) ? 0 : row;
    var _r2 = (row == -1) ? global.grid_rows - 1 : row;
    for (var _r = _r1; _r <= _r2; _r++) {
        for (var _c = _c1; _c <= _c2; _c++) {
            var _list = ds_grid_get(global.grid_plants, _c, _r);
            while (ds_list_size(_list) > 0) {
                var _plant = ds_list_find_value(_list, 0);
                card_destroyed(_plant);
                instance_destroy(_plant);
            }
        }
    }
}

/// @function VM_SetFlame(amount)
/// @param amount 设置的火苗数
function VM_SetFlame(amount_addr) {
    global.flame = vm_read_mem(global.__vm, amount_addr);
}

/// @function VM_Random(min, max)
/// @return [min, max] 之间随机整数
function VM_Random(min_addr, max_addr) {
    return irandom_range(vm_read_mem(global.__vm, min_addr), vm_read_mem(global.__vm, max_addr));
}

/// @function VM_GetLastIdlePlatform()
/// @return 刚结束 idle 的平台实例 ID
function VM_GetLastIdlePlatform() {
    return real(global._VM_last_idle_platform);
}

/// @function VM_SetPlatformParams(plat_id, axis, distance, idle, direction)
/// @param plat_id   平台实例 ID
/// @param axis      移动轴: 0=上下 1=左右
/// @param distance  移动距离（格）
/// @param idle      边界停顿时间（帧）
/// @param direction 移动方向: 1=正向 -1=反向
/// @description 以当前位置为新起点重新设定移动参数
function VM_SetPlatformParams(plat_id_addr, axis_addr, distance_addr, idle_addr, direction_addr) {
    var plat_id = vm_read_mem(global.__vm, plat_id_addr);
    var axis = vm_read_mem(global.__vm, axis_addr);
    var distance = vm_read_mem(global.__vm, distance_addr);
    var idle = vm_read_mem(global.__vm, idle_addr);
    var _direction = vm_read_mem(global.__vm, direction_addr);
    var _plat = plat_id;
    if (!instance_exists(_plat) || _plat.object_index != obj_platform) return;
    // 以当前位置为新起点
    var _is_x = (_plat.move_axis == "x");
    _plat.start_col += (_is_x ? _plat.current_offset : 0);
    _plat.start_row += (!_is_x ? _plat.current_offset : 0);
    _plat.current_offset = 0;
    // 设置新参数
    _plat.move_axis = (axis == 0) ? "y" : "x";
    _plat.move_distance = distance;
    _plat.boundary_idle_duration = idle;
    _plat.move_direction = _direction;
}

/// @function VM_GetWave()
/// @return 当前波次
function VM_GetWave() {
    return obj_battle.current_wave;
}

/// @function VM_GetSubwave()
/// @return 当前子波
function VM_GetSubwave() {
    return obj_battle.current_subwave;
}

/// @function VM_GetLastBoss()
/// @return 最新创建的 BOSS 实例 ID
function VM_GetLastBoss() {
    return  real(global._VM_last_boss);
}

/// @function VM_GetLastCreatedEnemy()
/// @return 最新创建的敌人实例 ID
function VM_GetLastCreatedEnemy() {
    return  real(global._VM_last_created_enemy);
}

/// @function VM_GetLastKilledEnemy()
/// @return 最新死亡的敌人实例 ID
function VM_GetLastKilledEnemy() {
    return  real(global._VM_last_killed_enemy);
}

/// @function VM_GetLastCreatedCard()
/// @return 最新创建的卡片实例 ID
function VM_GetLastCreatedCard() {
    return  real(global._VM_last_created_card);
}

/// @function VM_GetLastDestroyedCard()
/// @return 最新销毁的卡片实例 ID
function VM_GetLastDestroyedCard() {
    return  real(global._VM_last_destroyed_card);
}

/// @function VM_GetProp(inst_id, prop)
/// @return 属性值
function VM_GetProp(inst_id_addr, prop_addr) {
    var inst_id = vm_read_mem(global.__vm, inst_id_addr);
    var prop = vm_read_mem(global.__vm, prop_addr);
    if (!instance_exists(inst_id)) return undefined;
    return variable_instance_get(inst_id, prop);
}

/// @function VM_SetProp(inst_id, prop, value)
function VM_SetProp(inst_id_addr, prop_addr, value_addr) {
    var inst_id = vm_read_mem(global.__vm, inst_id_addr);
    var prop = vm_read_mem(global.__vm, prop_addr);
    var value = vm_read_mem(global.__vm, value_addr);
    if (!instance_exists(inst_id)) return;
    variable_instance_set(inst_id, prop, value);
    if (global.network.mode == "server") {
        var _nid = ds_map_exists(global.network.map_instance_id_net_id, inst_id) ? global.network.map_instance_id_net_id[? inst_id] : -1;
        if (_nid != -1) {
            var _s = {}; _s[$ prop] = value;
            var _json = json_stringify(_s);
            var _list = global.network.connected_clients;
            for (var _i = 0; _i < array_length(_list); _i++)
                send_message(_list[_i], MSG_MODIFY_PROP, _nid, _json);
        }
    }
}

/// @function VM_SpawnObject(obj_name, col, row)
/// @return 实例 ID
function VM_SpawnObject(obj_name_addr, col_addr, row_addr) {
    var obj_name = vm_read_mem(global.__vm, obj_name_addr);
    var col = vm_read_mem(global.__vm, col_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    if (global.network.mode == "client") return -1;
    if (!string_starts_with(obj_name, "obj_"))
        obj_name = "obj_" + obj_name;
    var _obj = asset_get_index(obj_name);
    if (_obj < 0) {
        show_debug_message("[VM_SpawnObject] 对象不存在: " + obj_name);
        return -1;
    }
    return real(spawn_plant(col, row, _obj, {}));
}

/// @function VM_SpawnPlant(card_id, col, row, shape, level, skill)
/// @return 植物实例 ID
function VM_SpawnPlant(card_id_addr, col_addr, row_addr, shape_addr, level_addr, skill_addr) {
    var card_id = vm_read_mem(global.__vm, card_id_addr);
    var col = vm_read_mem(global.__vm, col_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    var shape = vm_read_mem(global.__vm, shape_addr);
    var level = vm_read_mem(global.__vm, level_addr);
    var skill = vm_read_mem(global.__vm, skill_addr);
    if (global.network.mode == "client") return -1;
    if (is_undefined(shape)) shape = 0;
    if (is_undefined(level)) level = 0;
    if (is_undefined(skill)) skill = 0;
    var _card_data = deck_get_card_data(card_id, shape);
    if (is_undefined(_card_data)) return -1;
    var _obj = _card_data[? "obj"];
    var _props = { current_level: level, skill: skill };
    var _plant = spawn_plant(col, row, _obj, _props);
    global._VM_last_created_card = _plant;
    // card_created 已挂 hook，此处不重复
    return real(_plant);
}

/// @function VM_SpawnEnemy(type, row, hp_override)
/// @return 敌人实例 ID
function VM_SpawnEnemy(type_addr, row_addr, hp_override_addr) {
    var type = vm_read_mem(global.__vm, type_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    var hp_override = vm_read_mem(global.__vm, hp_override_addr);
    if (global.network.mode == "client") return -1;
    var _info = global.enemy_map[? type];
    if (is_undefined(_info)) return -1;
    var _pos = get_world_position_from_grid(global.grid_cols, row);
    var _enemy = instance_create_depth(_pos.x + 30, _pos.y + 38, 0, _info._obj);
    if (!is_undefined(hp_override) && hp_override > 0) {
        _enemy.hp = hp_override;
        _enemy.maxhp = hp_override;
    }
    if (global.network.mode == "server") {
        add_net_id(_enemy.id);
        var _nid = global.network.map_instance_id_net_id[? _enemy.id];
        var _list = global.network.connected_clients;
        for (var _i = 0; _i < array_length(_list); _i++)
            send_message(_list[_i], MSG_SPAWN_ENEMY, _nid, _pos.x + 30, _pos.y + 3, object_get_name(_info._obj));
    }
    global._VM_last_created_enemy = _enemy.id;
    if (buffer_exists(global._VM_ENEMY_SPAWNED)) VM_QueueHook(global._VM_ENEMY_SPAWNED, "enemy", _enemy.id);
    return real(_enemy.id);
}

/// @function VM_SpawnBoss(type, row, hp_override)
/// @return BOSS 实例 ID
function VM_SpawnBoss(type_addr, row_addr, hp_override_addr) {
    var type = vm_read_mem(global.__vm, type_addr);
    var row = vm_read_mem(global.__vm, row_addr);
    var hp_override = vm_read_mem(global.__vm, hp_override_addr);
    if (global.network.mode == "client") return -1;
    var _info = global.enemy_map[? type];
    if (is_undefined(_info)) return -1;
    var _pos = get_world_position_from_grid(10, row);
    var _boss = instance_create_depth(_pos.x - 80, _pos.y + 30, -200, _info._obj);
    if (!is_undefined(hp_override) && hp_override > 0) {
        _boss.hp = hp_override;
        _boss.maxhp = hp_override;
    }
    obj_battle.boss_count++;
    if (global.network.mode == "server") {
        add_net_id(_boss.id);
        var _nid = global.network.map_instance_id_net_id[? _boss.id];
        var _list = global.network.connected_clients;
        for (var _i = 0; _i < array_length(_list); _i++)
            send_message(_list[_i], MSG_SPAWN_BOSS, _nid, _pos.x - 80, _pos.y + 30, object_get_name(_info._obj), _boss.hp, _boss.maxhp, row);
    }
    global._VM_last_boss = _boss.id;
    return real(_boss.id);
}

// ============================================================
// 辅助：从内存地址读取值（按类型转换）
// ============================================================
function vm_read_mem(vm, addr) {
    var _type = vm.mem_type[addr];
    if (_type == VM_TYPE_STRING) {
        var _idx = vm.mem_val[addr];
        if (_idx >= 0 && _idx < array_length(vm.strings))
            return vm.strings[_idx];
        return "";
    }
    return vm.mem_val[addr];
}

/// @function VM_Execute(vm, buf)
function VM_Execute(vm, buf) {
    try {
        if (global._VM_debug_mode) return VM_Execute_debug(vm, buf);
        buffer_seek(buf, buffer_seek_start, 0);
        var _size = buffer_get_size(buf);
        var _mt = vm.mem_type;
        var _mv = vm.mem_val;
        var _mlen = array_length(_mt);

        while (buffer_tell(buf) < _size) {
            var _op = buffer_read(buf, buffer_u8);

            switch (_op) {

                // ==================== ASSIGN ====================
                case VM_OP_ASSIGN: {
                    var _dst = buffer_read(buf, buffer_s32);
                    var _type = buffer_read(buf, buffer_u8);
                    if (_type == VM_TYPE_STRING) {
                        _mt[_dst] = VM_TYPE_STRING;
                        _mv[_dst] = buffer_read(buf, buffer_u16);
                    } else  if (_type == VM_TYPE_FLOAT) {
						_mt[_dst] = VM_TYPE_FLOAT
						_mv[_dst] = buffer_read(buf, buffer_f32)
					} else {
						_mt[_dst] = _type
						_mv[_dst] = buffer_read(buf, buffer_s32)
					}

                    break;
                }

                // ==================== COPY ====================
                case VM_OP_COPY: {
                    var _dst = buffer_read(buf, buffer_s32);
                    var _src = buffer_read(buf, buffer_s32);
                    _mt[_dst] = _mt[_src];
                    _mv[_dst] = _mv[_src];
                    break;
                }

                // ==================== 算术 ====================
                case VM_OP_ADD: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _res = _mv[_a] + _mv[_b];
                    _mt[_d] = (_mt[_a] == VM_TYPE_FLOAT || _mt[_b] == VM_TYPE_FLOAT) ? VM_TYPE_FLOAT : VM_TYPE_INT;
                    _mv[_d] = _res;
                    break;
                }
                case VM_OP_SUB: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = (_mt[_a] == VM_TYPE_FLOAT || _mt[_b] == VM_TYPE_FLOAT) ? VM_TYPE_FLOAT : VM_TYPE_INT;
                    _mv[_d] = _mv[_a] - _mv[_b];
                    break;
                }
                case VM_OP_MUL: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = (_mt[_a] == VM_TYPE_FLOAT || _mt[_b] == VM_TYPE_FLOAT) ? VM_TYPE_FLOAT : VM_TYPE_INT;
                    _mv[_d] = _mv[_a] * _mv[_b];
                    break;
                }
                case VM_OP_DIV: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _int_div = (_mt[_a] != VM_TYPE_FLOAT && _mt[_b] != VM_TYPE_FLOAT);
                    if (_mv[_b] == 0) {
                        _mt[_d] = _int_div ? VM_TYPE_INT : VM_TYPE_FLOAT;
                        _mv[_d] = 0;
                    } else if (_int_div) {
                        _mt[_d] = VM_TYPE_INT;
                        _mv[_d] = _mv[_a] div _mv[_b];
                    } else {
                        _mt[_d] = VM_TYPE_FLOAT;
                        _mv[_d] = _mv[_a] / _mv[_b];
                    }
                    break;
                }
                case VM_OP_MOD: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_b] != 0) ? _mv[_a] mod _mv[_b] : 0;
                    break;
                }

                // ==================== 比较 ====================
                case VM_OP_EQ: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] == _mv[_b]) ? 1 : 0;
                    break;
                }
                case VM_OP_NEQ: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] != _mv[_b]) ? 1 : 0;
                    break;
                }
                case VM_OP_GT: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] > _mv[_b]) ? 1 : 0;
                    break;
                }
                case VM_OP_GTE: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] >= _mv[_b]) ? 1 : 0;
                    break;
                }
                case VM_OP_LT: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] < _mv[_b]) ? 1 : 0;
                    break;
                }
                case VM_OP_LTE: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] <= _mv[_b]) ? 1 : 0;
                    break;
                }

                // ==================== CALL ====================
                case VM_OP_CALL: {
                    var _func_id = buffer_read(buf, buffer_u16);
                    var _arg_count = buffer_read(buf, buffer_u8);
                    var _dst = buffer_read(buf, buffer_s32);
                    var _args = array_create(_arg_count);

                    for (var _i = 0; _i < _arg_count; _i++) {
                        var _addr = buffer_read(buf, buffer_s32);
                        _args[_i] = _addr;
                    }

                    if (_func_id < 0 || _func_id >= array_length(vm.functions)) {
                        shell_print("VM Error: 未注册函数ID " + string(_func_id));
                        return -1;
                    }

                    var _fn = vm.functions[_func_id];
                    var _result = script_execute_ext(_fn, _args);

                    if (_dst != VM_DST_VOID) {
                        var _ret_type = vm.func_ret_types[_func_id];
                        if (_ret_type == VM_TYPE_STRING) {
                            _mt[_dst] = VM_TYPE_STRING;
                        } else if (is_string(_result)) {
                            _mt[_dst] = VM_TYPE_STRING;
                        } else if (is_real(_result)) {
                            _mt[_dst] = VM_TYPE_INT;
                        }
                        _mv[_dst] = _result;
                    }
                    break;
                }

                // ==================== IF ====================
                case VM_OP_IF: {
                    var _cond_addr = buffer_read(buf, buffer_s32);
                    var _true_ip = buffer_read(buf, buffer_s32);
                    var _false_ip = buffer_read(buf, buffer_s32);

                    var _cond = _mv[_cond_addr];
                    if (!is_real(_cond)) _cond = 0;

                    if (_cond != 0) {
                        if (_true_ip != -1) {
                            buffer_seek(buf, buffer_seek_start, _true_ip);
                            continue;
                        }
                    } else {
                        if (_false_ip != -1) {
                            buffer_seek(buf, buffer_seek_start, _false_ip);
                            continue;
                        }
                    }
                    break;
                }

                // ==================== JMP ====================
                case VM_OP_JMP: {
                    var _ip = buffer_read(buf, buffer_s32);
                    buffer_seek(buf, buffer_seek_start, _ip);
                    continue;
                }

                // ==================== HALT ====================
                case VM_OP_HALT: {
                    return 0;
                }

                default: {
                    shell_print("VM Error: 未知操作码 " + string(_op));
                    return -1;
                }
            }
        }

        return 0;

    } catch (_err) {
        shell_print("VM Error: " + string(_err));
        return -1;
    }
}

/// @function VM_Execute_debug(vm, buf) [DEBUG VERSION]
function VM_Execute_debug(vm, buf) {
    try {
        buffer_seek(buf, buffer_seek_start, 0);
        var _size = buffer_get_size(buf);
        var _mt = vm.mem_type;
        var _mv = vm.mem_val;

        while (buffer_tell(buf) < _size) {
            var _pos = buffer_tell(buf);
            var _op = buffer_read(buf, buffer_u8);

            switch (_op) {

                case VM_OP_ASSIGN: {
                    var _dst = buffer_read(buf, buffer_s32);
                    var _type = buffer_read(buf, buffer_u8);
                    if (_type == VM_TYPE_STRING) {
                        var _val = buffer_read(buf, buffer_u16);
                        _mt[_dst] = VM_TYPE_STRING;
                        _mv[_dst] = _val;
                        shell_print("[" + string(_pos) + "] ASSIGN var" + string(_dst) + " = str" + string(_val) + " \"" + vm.strings[_val] + "\"");
                    } else if (_type == VM_TYPE_FLOAT) {
                        var _val = buffer_read(buf, buffer_f32);
                        _mt[_dst] = VM_TYPE_FLOAT;
                        _mv[_dst] = _val;
                        shell_print("[" + string(_pos) + "] ASSIGN var" + string(_dst) + " = " + string(_val) + "f");
                    } else {
                        var _val = buffer_read(buf, buffer_s32);
                        _mt[_dst] = _type;
                        _mv[_dst] = _val;
                        shell_print("[" + string(_pos) + "] ASSIGN var" + string(_dst) + " = " + string(_val));
                    }
                    break;
                }

                case VM_OP_COPY: {
                    var _dst = buffer_read(buf, buffer_s32);
                    var _src = buffer_read(buf, buffer_s32);
                    var _src_val = _mv[_src];
                    _mt[_dst] = _mt[_src];
                    _mv[_dst] = _src_val;
                    shell_print("[" + string(_pos) + "] COPY  var" + string(_dst) + " = var" + string(_src) + " (" + string(_src_val) + ")");
                    break;
                }

                case VM_OP_ADD: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b]; var _res = _av + _bv;
                    _mt[_d] = (_mt[_a] == VM_TYPE_FLOAT || _mt[_b] == VM_TYPE_FLOAT) ? VM_TYPE_FLOAT : VM_TYPE_INT;
                    _mv[_d] = _res;
                    shell_print("[" + string(_pos) + "] ADD   var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") + var" + string(_b) + "(" + string(_bv) + ") = " + string(_res));
                    break;
                }
                case VM_OP_SUB: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b];
                    _mt[_d] = (_mt[_a] == VM_TYPE_FLOAT || _mt[_b] == VM_TYPE_FLOAT) ? VM_TYPE_FLOAT : VM_TYPE_INT;
                    _mv[_d] = _av - _bv;
                    shell_print("[" + string(_pos) + "] SUB   var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") - var" + string(_b) + "(" + string(_bv) + ") = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_MUL: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b];
                    _mt[_d] = (_mt[_a] == VM_TYPE_FLOAT || _mt[_b] == VM_TYPE_FLOAT) ? VM_TYPE_FLOAT : VM_TYPE_INT;
                    _mv[_d] = _av * _bv;
                    shell_print("[" + string(_pos) + "] MUL   var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") * var" + string(_b) + "(" + string(_bv) + ") = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_DIV: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b];
                    var _int_div = (_mt[_a] != VM_TYPE_FLOAT && _mt[_b] != VM_TYPE_FLOAT);
                    if (_bv == 0) {
                        _mt[_d] = _int_div ? VM_TYPE_INT : VM_TYPE_FLOAT;
                        _mv[_d] = 0;
                        shell_print("[" + string(_pos) + "] DIV   var" + string(_d) + " = var" + string(_a) + " / var" + string(_b) + " = 0 (div0)");
                    } else if (_int_div) {
                        _mt[_d] = VM_TYPE_INT;
                        _mv[_d] = _av div _bv;
                        shell_print("[" + string(_pos) + "] DIV   var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") div var" + string(_b) + "(" + string(_bv) + ") = " + string(_mv[_d]));
                    } else {
                        _mt[_d] = VM_TYPE_FLOAT;
                        _mv[_d] = _av / _bv;
                        shell_print("[" + string(_pos) + "] DIV   var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") / var" + string(_b) + "(" + string(_bv) + ") = " + string(_mv[_d]));
                    }
                    break;
                }
                case VM_OP_MOD: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b];
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_bv != 0) ? _av mod _bv : 0;
                    shell_print("[" + string(_pos) + "] MOD   var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") % var" + string(_b) + "(" + string(_bv) + ") = " + string(_mv[_d]));
                    break;
                }

                case VM_OP_EQ: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b];
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_av == _bv) ? 1 : 0;
                    shell_print("[" + string(_pos) + "] EQ    var" + string(_d) + " = var" + string(_a) + "(" + string(_av) + ") == var" + string(_b) + "(" + string(_bv) + ") = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_NEQ: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    var _av = _mv[_a]; var _bv = _mv[_b];
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_av != _bv) ? 1 : 0;
                    shell_print("[" + string(_pos) + "] NEQ   var" + string(_d) + " = var" + string(_a) + " != var" + string(_b) + " = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_GT: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] > _mv[_b]) ? 1 : 0;
                    shell_print("[" + string(_pos) + "] GT    var" + string(_d) + " = var" + string(_a) + " > var" + string(_b) + " = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_GTE: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] >= _mv[_b]) ? 1 : 0;
                    shell_print("[" + string(_pos) + "] GTE   var" + string(_d) + " = var" + string(_a) + " >= var" + string(_b) + " = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_LT: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] < _mv[_b]) ? 1 : 0;
                    shell_print("[" + string(_pos) + "] LT    var" + string(_d) + " = var" + string(_a) + " < var" + string(_b) + " = " + string(_mv[_d]));
                    break;
                }
                case VM_OP_LTE: {
                    var _d = buffer_read(buf, buffer_s32);
                    var _a = buffer_read(buf, buffer_s32);
                    var _b = buffer_read(buf, buffer_s32);
                    _mt[_d] = VM_TYPE_INT;
                    _mv[_d] = (_mv[_a] <= _mv[_b]) ? 1 : 0;
                    shell_print("[" + string(_pos) + "] LTE   var" + string(_d) + " = var" + string(_a) + " <= var" + string(_b) + " = " + string(_mv[_d]));
                    break;
                }

                case VM_OP_CALL: {
                    var _func_id = buffer_read(buf, buffer_u16);
                    var _arg_count = buffer_read(buf, buffer_u8);
                    var _dst = buffer_read(buf, buffer_s32);
                    var _args = array_create(_arg_count);
                    var _arg_str = "";

                    for (var _i = 0; _i < _arg_count; _i++) {
                        var _addr = buffer_read(buf, buffer_s32);
                        _args[_i] = _addr;
                        var _val = vm_read_mem(vm, _addr);
                        _arg_str += " var" + string(_addr) + "(" + string(_val) + ")";
                    }

                    if (_func_id < 0 || _func_id >= array_length(vm.functions)) {
                        shell_print("VM Error: bad func_id " + string(_func_id));
                        return -1;
                    }

                    var _fn = vm.functions[_func_id];
                    var _result = script_execute_ext(_fn, _args);
                    var _dst_str = (_dst == VM_DST_VOID) ? "void" : "var" + string(_dst);

                    shell_print("[" + string(_pos) + "] CALL  func" + string(_func_id) + _arg_str + " -> " + _dst_str + " = " + string(_result));

                    if (_dst != VM_DST_VOID) {
                        var _ret_type = vm.func_ret_types[_func_id];
                        if (_ret_type == VM_TYPE_STRING) {
                            _mt[_dst] = VM_TYPE_STRING;
                        } else if (is_string(_result)) {
                            _mt[_dst] = VM_TYPE_STRING;
                        } else if (is_real(_result)) {
                            _mt[_dst] = VM_TYPE_INT;
                        }
                        _mv[_dst] = _result;
                    }
                    break;
                }

                case VM_OP_IF: {
                    var _cond_addr = buffer_read(buf, buffer_s32);
                    var _true_ip = buffer_read(buf, buffer_s32);
                    var _false_ip = buffer_read(buf, buffer_s32);

                    var _cond = _mv[_cond_addr];
                    if (!is_real(_cond)) _cond = 0;

                    shell_print("[" + string(_pos) + "] IF    var" + string(_cond_addr) + "(" + string(_cond) + ") ? goto " + string(_true_ip) + " : goto " + string(_false_ip));

                    if (_cond != 0) {
                        if (_true_ip != -1) {
                            buffer_seek(buf, buffer_seek_start, _true_ip);
                            continue;
                        }
                    } else {
                        if (_false_ip != -1) {
                            buffer_seek(buf, buffer_seek_start, _false_ip);
                            continue;
                        }
                    }
                    break;
                }

                case VM_OP_JMP: {
                    var _ip = buffer_read(buf, buffer_s32);
                    shell_print("[" + string(_pos) + "] JMP   goto " + string(_ip));
                    buffer_seek(buf, buffer_seek_start, _ip);
                    continue;
                }

                case VM_OP_HALT: {
                    shell_print("[" + string(_pos) + "] HALT");
                    return 0;
                }

                default: {
                    shell_print("VM Error: unknown op " + string(_op));
                    return -1;
                }
            }
        }
        return 0;
    } catch (_err) {
        shell_print("VM Error: " + string(_err));
        return -1;
    }
}

// ============================================================
// 全局初始化和块管理
// ============================================================
global.banned_cards_online = ds_map_create();
global._VM_card_level_cap = -1;
global._VM_max_slots = -1;
global._VM_strings = [];

global._VM_ROOM_READY_ENTRY = undefined;
global._VM_room_ready_done   = false;
global._VM_BATTLE_START        = undefined;
global._VM_battle_start_done    = false;
global._VM_CARD_CREATED      = undefined;
global._VM_CARD_DESTROYED    = undefined;
global._VM_CARD_DAMAGED      = undefined;
global._VM_ENEMY_SPAWNED     = undefined;
global._VM_ENEMY_KILLED      = undefined;
global._VM_ENEMY_DAMAGED     = undefined;
global._VM_WAVE_START        = undefined;
global._VM_WAVE_END          = undefined;
global._VM_SUBWAVE_START     = undefined;
global._VM_SUBWAVE_END       = undefined;
global._VM_PLAYER_DAMAGED    = undefined;
global._VM_PLATFORM_IDLE_END = undefined;
global._VM_FRAME             = undefined;
global._VM_last_idle_platform = -1;

global._VM_debug_mode = false;
global._VM_loaded_sprite_indices = [];
global._VM_hook_queue = [];       // 待执行 hook 队列，每个元素 {buf, id}

function VM_QueueHook(buf, key, id) {
    if (buffer_exists(buf)) array_push(global._VM_hook_queue, {buf: buf, key: key, id: id});
}

/**
 * Function Description
 */
function VM_FlushHooks() {
    while (array_length(global._VM_hook_queue) > 0) {
        var _q = global._VM_hook_queue;
        global._VM_hook_queue = [];
        for (var _i = 0; _i < array_length(_q); _i++) {
            var _e = _q[_i];
            if (_e.key == "card")        global._VM_last_created_card   = _e.id;
            if (_e.key == "card_del")    global._VM_last_destroyed_card = _e.id;
            if (_e.key == "enemy")       global._VM_last_created_enemy  = _e.id;
            if (_e.key == "enemy_kill")  global._VM_last_killed_enemy   = _e.id;
            if (_e.key == "platform_idle") global._VM_last_idle_platform = _e.id;
            VM_Execute(global.__vm, _e.buf);
        }
    }
}

global._VM_last_boss          = -1;
global._VM_last_created_enemy = -1;
global._VM_last_killed_enemy  = -1;
global._VM_last_created_card  = -1;
global._VM_last_destroyed_card = -1;

global.__vm = VM_Create();
VM_RegisterFunction(global.__vm, VM_BanCard);         // 0
VM_RegisterFunction(global.__vm, VM_SetCardLevelCap);  // 1
VM_RegisterFunction(global.__vm, VM_SetMaxSlots);       // 2
VM_RegisterFunction(global.__vm, VM_ShellPrint);        // 3
VM_RegisterFunction(global.__vm, VM_ShowNotice);        // 4
VM_RegisterFunction(global.__vm, VM_CreatePlatform);    // 5
VM_RegisterFunction(global.__vm, VM_SpawnPlant);       // 6
VM_RegisterFunction(global.__vm, VM_SpawnEnemy);       // 7
VM_RegisterFunction(global.__vm, VM_SpawnBoss);        // 8
VM_RegisterFunction(global.__vm, VM_LoadSprite);       // 9
VM_RegisterFunction(global.__vm, VM_SpawnObject);      // 10
VM_RegisterFunction(global.__vm, VM_SetProp);          // 11
VM_RegisterFunction(global.__vm, VM_GetWave);               // 12
VM_RegisterFunction(global.__vm, VM_GetSubwave);            // 13
VM_RegisterFunction(global.__vm, VM_GetProp);               // 14
VM_RegisterFunction(global.__vm, VM_GetLastBoss);           // 15
VM_RegisterFunction(global.__vm, VM_GetLastCreatedEnemy);   // 16
VM_RegisterFunction(global.__vm, VM_GetLastKilledEnemy);    // 17
VM_RegisterFunction(global.__vm, VM_GetLastCreatedCard);    // 18
VM_RegisterFunction(global.__vm, VM_GetLastDestroyedCard);  // 19
VM_RegisterFunction(global.__vm, VM_GetFlame);              // 20
VM_RegisterFunction(global.__vm, VM_SetFlame);              // 21
VM_RegisterFunction(global.__vm, VM_SetTerrain);            // 22
VM_RegisterFunction(global.__vm, VM_ClearPlants);           // 23
VM_RegisterFunction(global.__vm, VM_Random);                // 24
VM_RegisterFunction(global.__vm, VM_GetLastIdlePlatform);   // 25
VM_RegisterFunction(global.__vm, VM_SetPlatformParams);     // 26
VM_RegisterFunction(global.__vm, VM_SetMapBackground);      // 27
VM_RegisterFunction(global.__vm, VM_SetDrawSlot);           // 28
VM_RegisterFunction(global.__vm, VM_GetLoadedSpriteName, VM_TYPE_STRING);   // 29
global._sync_vm_bin_buf = undefined;

/// @function VM_InitRoomEntry(buf)
function VM_InitRoomEntry(buf) {
    ds_map_clear(global.banned_cards_online);
    global._VM_card_level_cap = -1;
    global._VM_max_slots = -1;
    global._VM_ROOM_READY_ENTRY = undefined;
    global._VM_room_ready_done   = false;
    global._VM_BATTLE_START      = undefined;
    global._VM_CARD_CREATED      = undefined;
    global._VM_CARD_DESTROYED    = undefined;
    global._VM_CARD_DAMAGED      = undefined;
    global._VM_ENEMY_SPAWNED     = undefined;
    global._VM_ENEMY_KILLED      = undefined;
    global._VM_ENEMY_DAMAGED     = undefined;
    global._VM_WAVE_START        = undefined;
    global._VM_WAVE_END          = undefined;
    global._VM_SUBWAVE_START     = undefined;
    global._VM_SUBWAVE_END       = undefined;
    global._VM_PLAYER_DAMAGED    = undefined;
    global._VM_PLATFORM_IDLE_END = undefined;
    global._VM_FRAME             = undefined;
    global._sync_vm_bin_buf = undefined;
    global._VM_strings = [];
    global.__vm.strings = global._VM_strings;
    global.__vm.mem_type = array_create(array_length(global.__vm.mem_type), VM_TYPE_INT);
    global.__vm.mem_val  = array_create(array_length(global.__vm.mem_val), 0);
    global._VM_loaded_sprite_indices = [];
    global._VM_hook_queue = [];
    global._VM_battle_start_done = false;
    global._VM_last_boss          = -1;
    global._VM_last_created_enemy = -1;
    global._VM_last_killed_enemy  = -1;
    global._VM_last_created_card  = -1;
    global._VM_last_destroyed_card = -1;
    global._VM_last_idle_platform = -1;

    if (!buffer_exists(buf)) return;

    buffer_seek(buf, buffer_seek_start, 0);
    var _buf_size = buffer_get_size(buf);

    // ---- 读字符串池 ----
    var _str_count = buffer_read(buf, buffer_s32);
    for (var _i = 0; _i < _str_count; _i++) {
        var _len = buffer_read(buf, buffer_s32);
        var _tmp = buffer_create(_len + 1, buffer_fixed, 1);
        for (var _j = 0; _j < _len; _j++) {
            buffer_write(_tmp, buffer_u8, buffer_read(buf, buffer_u8));
        }
        buffer_write(_tmp, buffer_u8, 0);
        buffer_seek(_tmp, buffer_seek_start, 0);
        array_push(global._VM_strings, buffer_read(_tmp, buffer_string));
        buffer_delete(_tmp);
    }

    // 字符串池里包含 "debug" 则开启调试模式
    global._VM_debug_mode = false;
    for (var _i = 0; _i < array_length(global._VM_strings); _i++) {
        if (global._VM_strings[_i] == "debug") { global._VM_debug_mode = true; break; }
    }

    // ---- 读块数据 ----
    while (buffer_tell(buf) < _buf_size) {
        var _block_len = buffer_read(buf, buffer_s32);
        var _name_idx  = buffer_read(buf, buffer_s32);

        var _block_name = "";
        if (_name_idx >= 0 && _name_idx < array_length(global._VM_strings)) {
            _block_name = global._VM_strings[_name_idx];
        }

        var _bc_buf = buffer_create(_block_len, buffer_fixed, 1);
        for (var _j = 0; _j < _block_len; _j++) {
            buffer_write(_bc_buf, buffer_u8, buffer_read(buf, buffer_u8));
        }
        buffer_seek(_bc_buf, buffer_seek_start, 0);

        switch (_block_name) {
            case "_VM_ROOM_READY_ENTRY":
                global._VM_ROOM_READY_ENTRY = _bc_buf;
                VM_Execute(global.__vm, _bc_buf);
                break;
            case "_VM_BATTLE_START":
                global._VM_BATTLE_START = _bc_buf;
                break;
            case "_VM_CARD_CREATED":
                global._VM_CARD_CREATED = _bc_buf;
                break;
            case "_VM_CARD_DESTROYED":
                global._VM_CARD_DESTROYED = _bc_buf;
                break;
            case "_VM_CARD_DAMAGED":
                global._VM_CARD_DAMAGED = _bc_buf;
                break;
            case "_VM_ENEMY_SPAWNED":
                global._VM_ENEMY_SPAWNED = _bc_buf;
                break;
            case "_VM_ENEMY_KILLED":
                global._VM_ENEMY_KILLED = _bc_buf;
                break;
            case "_VM_ENEMY_DAMAGED":
                global._VM_ENEMY_DAMAGED = _bc_buf;
                break;
            case "_VM_WAVE_START":
                global._VM_WAVE_START = _bc_buf;
                break;
            case "_VM_WAVE_END":
                global._VM_WAVE_END = _bc_buf;
                break;
            case "_VM_SUBWAVE_START":
                global._VM_SUBWAVE_START = _bc_buf;
                break;
            case "_VM_SUBWAVE_END":
                global._VM_SUBWAVE_END = _bc_buf;
                break;
            case "_VM_PLAYER_DAMAGED":
                global._VM_PLAYER_DAMAGED = _bc_buf;
                break;
            case "_VM_PLATFORM_IDLE_END":
                global._VM_PLATFORM_IDLE_END = _bc_buf;
                break;
            case "_VM_FRAME":
                global._VM_FRAME = _bc_buf;
                break;
            default:
                buffer_delete(_bc_buf);
                break;
        }
    }
}
