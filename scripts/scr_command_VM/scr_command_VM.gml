// ============================================================
// VM — 二进制字节码虚拟机
// 操作: CALL / IF / ASSIGN / MEM_WRITE / MEM_READ / HALT
// 代码存 buffer（二进制），内存存 array
// ============================================================

// 操作码 (u8)
#macro VM_OP_CALL       1
#macro VM_OP_IF         2
#macro VM_OP_ASSIGN     3
#macro VM_OP_MEM_WRITE  4
#macro VM_OP_MEM_READ   5
#macro VM_OP_HALT       6

// 值类型标签 (u8)
#macro VM_VAL_IMMEDIATE  0x10   // 后跟 s32
#macro VM_VAL_REGISTER   0x12   // 后跟 u8 寄存器ID

// 寄存器 ID (u8)
#macro VM_REG_R0     0
#macro VM_REG_R1     1
#macro VM_REG_R2     2
#macro VM_REG_R3     3
#macro VM_REG_RESULT 4

/// @function VM_RegName(id)
function VM_RegName(id) {
	switch (id) {
		case 0: return "R0";
		case 1: return "R1";
		case 2: return "R2";
		case 3: return "R3";
		case 4: return "RESULT";
	}
	return "R0";
}

/// @function VM_Create()
function VM_Create() {
	var vm = {
		registers: ds_map_create(),
		memory: [],
		function_map: ds_map_create(),
	};

	ds_map_set(vm.registers, "R0", 0);
	ds_map_set(vm.registers, "R1", 0);
	ds_map_set(vm.registers, "R2", 0);
	ds_map_set(vm.registers, "R3", 0);
	ds_map_set(vm.registers, "RESULT", 0);

	return vm;
}

/// @function VM_RegisterFunction(vm, func_name, script_func)
function VM_RegisterFunction(vm, func_name, script_func) {
	ds_map_set(vm.function_map, func_name, script_func);
}

// ---- 寄存器读写 ----

function VM_GetReg(vm, id) {
	var _name = VM_RegName(id);
	if (ds_map_exists(vm.registers, _name)) {
		return ds_map_find_value(vm.registers, _name);
	}
	return 0;
}

function VM_SetReg(vm, id, value) {
	ds_map_set(vm.registers, VM_RegName(id), value);
}

// ---- 从 buffer 读取一个值 ----

function VM_ReadValue(vm, buf) {
	var _type = buffer_read(buf, buffer_u8);
	switch (_type) {
		case VM_VAL_IMMEDIATE:
			return buffer_read(buf, buffer_s32);
		case VM_VAL_REGISTER: {
			var _reg = buffer_read(buf, buffer_u8);
			return VM_GetReg(vm, _reg);
		}
		default:
			shell_print("VM Error: 未知值类型 " + string(_type));
			return 0;
	}
}

// ---- 向 buffer 写入一个值 ----

function VM_WriteValue(buf, val) {
	if (is_string(val) && string_char_at(val, 1) == "R") {
		// 寄存器引用: "R0"~"R3", "RESULT"
		var _id;
		switch (val) {
			case "R0": _id = 0; break;
			case "R1": _id = 1; break;
			case "R2": _id = 2; break;
			case "R3": _id = 3; break;
			case "RESULT": _id = 4; break;
			default: _id = 0;
		}
		buffer_write(buf, buffer_u8, VM_VAL_REGISTER);
		buffer_write(buf, buffer_u8, _id);
	} else {
		buffer_write(buf, buffer_u8, VM_VAL_IMMEDIATE);
		buffer_write(buf, buffer_s32, val);
	}
}

// ============================================================
// 编码: struct 数组 → 二进制 buffer
// ============================================================

function VM_Encode(vm, code) {
	// ---- 第一遍：计算每条指令的字节偏移 ----
	var _offsets = [];
	var _pos = 0;
	var _len = array_length(code);

	for (var _i = 0; _i < _len; _i++) {
		_offsets[_i] = _pos;
		var _inst = code[_i];
		var _op = _inst[$ "op"];

		_pos += 1; // op(u8)

		switch (_op) {
			case "CALL":
				_pos += 1 + string_length(_inst[$ "func"]) + 1;  // func_len + func_name
				_pos += 1;  // arg_count
				_pos += array_length(_inst[$ "args"]) * (VM_EncodeValueSize(_inst[$ "args"]));
				_pos += 1;  // target_reg
				break;
			case "IF":
				_pos += VM_EncodeValueSize([_inst[$ "cond"]]);
				_pos += 4 + 4;  // true_ip + false_ip
				break;
			case "ASSIGN":
				_pos += 1;  // target_reg
				_pos += VM_EncodeValueSize([_inst[$ "value"]]);
				break;
			case "MEM_WRITE":
				_pos += VM_EncodeValueSize([_inst[$ "index"]]);
				_pos += VM_EncodeValueSize([_inst[$ "value"]]);
				break;
			case "MEM_READ":
				_pos += VM_EncodeValueSize([_inst[$ "index"]]);
				_pos += 1;  // target_reg
				break;
			case "HALT":
				break;
		}
	}

	// ---- 第二遍：实际编码 ----
	var _buf = buffer_create(_pos + 16, buffer_fixed, 1);

	for (var _i = 0; _i < _len; _i++) {
		var _inst = code[_i];
		var _op = _inst[$ "op"];

		switch (_op) {

			case "CALL": {
				buffer_write(_buf, buffer_u8, VM_OP_CALL);
				var _name = _inst[$ "func"];
				buffer_write(_buf, buffer_u8, string_length(_name));
				buffer_write(_buf, buffer_string, _name);
				var _args = _inst[$ "args"];
				buffer_write(_buf, buffer_u8, array_length(_args));
				for (var _ai = 0; _ai < array_length(_args); _ai++) {
					VM_WriteValue(_buf, _args[_ai]);
				}
				buffer_write(_buf, buffer_u8, VM_RegID(_inst[$ "target"]));
				break;
			}

			case "IF": {
				buffer_write(_buf, buffer_u8, VM_OP_IF);
				VM_WriteValue(_buf, _inst[$ "cond"]);
				var _true_idx  = _inst[$ "true"];
				var _false_idx = _inst[$ "false"];
				buffer_write(_buf, buffer_s32, (_true_idx  != -1) ? _offsets[_true_idx]  : -1);
				buffer_write(_buf, buffer_s32, (_false_idx != -1) ? _offsets[_false_idx] : -1);
				break;
			}

			case "ASSIGN": {
				buffer_write(_buf, buffer_u8, VM_OP_ASSIGN);
				buffer_write(_buf, buffer_u8, VM_RegID(_inst[$ "target"]));
				VM_WriteValue(_buf, _inst[$ "value"]);
				break;
			}

			case "MEM_WRITE": {
				buffer_write(_buf, buffer_u8, VM_OP_MEM_WRITE);
				VM_WriteValue(_buf, _inst[$ "index"]);
				VM_WriteValue(_buf, _inst[$ "value"]);
				break;
			}

			case "MEM_READ": {
				buffer_write(_buf, buffer_u8, VM_OP_MEM_READ);
				VM_WriteValue(_buf, _inst[$ "index"]);
				buffer_write(_buf, buffer_u8, VM_RegID(_inst[$ "target"]));
				break;
			}

			case "HALT": {
				buffer_write(_buf, buffer_u8, VM_OP_HALT);
				break;
			}

			default: {
				shell_print("VM Encode Error: 未知操作 " + string(_op));
			}
		}
	}

	return _buf;
}

/// @function VM_RegID(name)  寄存器名 → u8 ID
function VM_RegID(name) {
	switch (name) {
		case "R0": return 0;
		case "R1": return 1;
		case "R2": return 2;
		case "R3": return 3;
		case "RESULT": return 4;
	}
	return 0;
}

/// @function VM_EncodeValueSize(vals)  计算值的编码长度
function VM_EncodeValueSize(vals) {
	var _sum = 0;
	for (var _i = 0; _i < array_length(vals); _i++) {
		var _v = vals[_i];
		if (is_string(_v) && string_char_at(_v, 1) == "R") {
			_sum += 1 + 1;  // type(u8) + reg_id(u8)
		} else {
			_sum += 1 + 4;  // type(u8) + s32
		}
	}
	return _sum;
}

// ============================================================
// 执行: 从二进制 buffer 读取并执行
// ============================================================

function VM_Execute(vm, buf) {
	try {
		buffer_seek(buf, buffer_seek_start, 0);
		var _size = buffer_get_size(buf);

		while (buffer_tell(buf) < _size) {
			var _op = buffer_read(buf, buffer_u8);

			switch (_op) {

				case VM_OP_CALL: {
					var _func_len = buffer_read(buf, buffer_u8);
					var _func_name = buffer_read(buf, buffer_string);
					if (string_length(_func_name) > _func_len) {
						_func_name = string_copy(_func_name, 1, _func_len);
					}
					var _arg_count = buffer_read(buf, buffer_u8);
					var _args = [];
					for (var _ai = 0; _ai < _arg_count; _ai++) {
						array_push(_args, VM_ReadValue(vm, buf));
					}
					var _target_reg = buffer_read(buf, buffer_u8);

					if (ds_map_exists(vm.function_map, _func_name)) {
						var _fn = ds_map_find_value(vm.function_map, _func_name);
						var _result = script_execute_ext(_fn, _args);
						VM_SetReg(vm, _target_reg, _result);
						VM_SetReg(vm, VM_REG_RESULT, _result);
					} else {
						shell_print("VM Error: 未注册函数 " + _func_name);
					}
					break;
				}

				case VM_OP_IF: {
					var _cond = VM_ReadValue(vm, buf);
					var _true_ip  = buffer_read(buf, buffer_s32);
					var _false_ip = buffer_read(buf, buffer_s32);

					if (_cond != 0 && _cond != false) {
						if (_true_ip != -1) { buffer_seek(buf, buffer_seek_start, _true_ip); continue; }
					} else {
						if (_false_ip != -1) { buffer_seek(buf, buffer_seek_start, _false_ip); continue; }
					}
					break;
				}

				case VM_OP_ASSIGN: {
					var _target_reg = buffer_read(buf, buffer_u8);
					var _val = VM_ReadValue(vm, buf);
					VM_SetReg(vm, _target_reg, _val);
					break;
				}

				case VM_OP_MEM_WRITE: {
					var _idx = VM_ReadValue(vm, buf);
					var _val = VM_ReadValue(vm, buf);
					vm.memory[_idx] = _val;
					break;
				}

				case VM_OP_MEM_READ: {
					var _idx = VM_ReadValue(vm, buf);
					var _target_reg = buffer_read(buf, buffer_u8);
					var _val = vm.memory[_idx];
					if (is_undefined(_val)) _val = 0;
					VM_SetReg(vm, _target_reg, _val);
					break;
				}

				case VM_OP_HALT: {
					return VM_GetReg(vm, VM_REG_RESULT);
				}

				default: {
					shell_print("VM Error: 未知操作码 " + string(_op));
					return -1;
				}
			}
		}

		return VM_GetReg(vm, VM_REG_RESULT);

	} catch (_err) {
		shell_print("VM Error: " + string(_err));
		return -1;
	}
}

/// @function VM_Destroy(vm)
function VM_Destroy(vm) {
	ds_map_destroy(vm.registers);
	ds_map_destroy(vm.function_map);
}

// ============================================================
// 使用示例
// ============================================================
/*
var vm = VM_Create();
VM_RegisterFunction(vm, "add",  function(a, b) { return a + b; });
VM_RegisterFunction(vm, "mult", function(a, b) { return a * b; });

// struct 格式 → 编码为二进制
var code = [
	{ op: "ASSIGN", target: "R0", value: 10 },
	{ op: "ASSIGN", target: "R1", value: 20 },
	{ op: "CALL", func: "add", args: ["R0", "R1"], target: "R2" },
	{ op: "IF", cond: "R2", true: 5, false: -1 },
	{ op: "CALL", func: "mult", args: ["R2", 2], target: "R2" },
	{ op: "MEM_WRITE", index: 0, value: "R2" },
	{ op: "MEM_READ", index: 0, target: "R3" },
	{ op: "HALT" },
];

var buf = VM_Encode(vm, code);
var result = VM_Execute(vm, buf);
show_debug_message("Result: " + string(result));

buffer_delete(buf);
VM_Destroy(vm);
*/
