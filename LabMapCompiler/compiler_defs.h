#pragma once
#include <string>
#include <vector>

// ============================================================
// 操作码 — 和 VM 端保持一致
// ============================================================
enum Opcode {
    OP_ASSIGN   = 1,   // dst(u32) type(u8) value(s32/u16)
    OP_COPY     = 2,   // dst(u32) src(u32)
    OP_ADD      = 3,   // dst(u32) a(u32) b(u32)
    OP_SUB      = 4,
    OP_MUL      = 5,
    OP_DIV      = 6,
    OP_MOD      = 7,
    OP_EQ       = 8,
    OP_NEQ      = 9,
    OP_GT       = 10,
    OP_GTE      = 11,
    OP_LT       = 12,
    OP_LTE      = 13,
    OP_CALL     = 14,  // func_id(u16) arg_count(u8) dst(s32) [addr(s32)*]
    OP_IF       = 15,  // cond_addr(u32) true_ip(s32) false_ip(s32)
    OP_JMP      = 16,
    OP_HALT     = 17,
};

// 内存类型
enum MemType {
    MEM_INT    = 0,
    MEM_FLOAT  = 1,
    MEM_STRING = 2,
};

// CALL dst 特殊值
static const int VOID_DST = -1;

// ============================================================
// 函数定义（仅游戏 API，算术已内联为操作码）
// ============================================================
struct FuncDef {
    const char* name;
    int param_count;  // 期望参数个数，0=变长（不校验）
    // 所有参数在字节码中都是内存地址(u32)
};

// ============================================================
// 块名表
// ============================================================
static const std::vector<const char*> BLOCK_NAMES = {
    "_VM_ROOM_READY_ENTRY",
    "_VM_BATTLE_START",
    "_VM_CARD_CREATED",
    "_VM_CARD_DESTROYED",
    "_VM_CARD_DAMAGED",
    "_VM_ENEMY_SPAWNED",
    "_VM_ENEMY_KILLED",
    "_VM_ENEMY_DAMAGED",
    "_VM_WAVE_START",
    "_VM_WAVE_END",
    "_VM_SUBWAVE_START",
    "_VM_SUBWAVE_END",
    "_VM_PLAYER_DAMAGED",
};

// ============================================================
// 函数名表 — 顺序必须和 VM 端注册顺序一致
// ============================================================
static std::vector<FuncDef> FUNC_DEFS = {
    {"VM_BanCard",        1},   // 0
    {"VM_SetCardLevelCap",1},   // 1
    {"VM_SetMaxSlots",    1},   // 2
    {"VM_ShellPrint",     0},   // 3 — 变长
    {"VM_ShowNotice",     0},   // 4 — 变长
    {"VM_CreatePlatform", 8},   // 5
    {"VM_SpawnPlant",    6},   // 6
    {"VM_SpawnEnemy",    3},   // 7
    {"VM_SpawnBoss",     3},   // 8
    {"VM_LoadSprite",    1},   // 9
    {"VM_SpawnObject",   3},   // 10
    {"VM_SetProp",       3},   // 11
    {"VM_GetWave",             0},   // 12
    {"VM_GetSubwave",          0},   // 13
    {"VM_GetProp",             2},   // 14
    {"VM_GetLastBoss",         0},   // 15
    {"VM_GetLastCreatedEnemy", 0},   // 16
    {"VM_GetLastKilledEnemy",  0},   // 17
    {"VM_GetLastCreatedCard",  0},   // 18
    {"VM_GetLastDestroyedCard",0},   // 19
    {"VM_GetFlame",          0},   // 20
    {"VM_SetFlame",          1},   // 21
    {"VM_SetTerrain",        3},   // 22
    {"VM_ClearPlants",       2},   // 23
    {"VM_Random",            2},   // 24
};

// ============================================================
// 查询函数
// ============================================================
inline int find_block(const std::string& name) {
    for (int i = 0; i < (int)BLOCK_NAMES.size(); i++)
        if (name == BLOCK_NAMES[i]) return i;
    return -1;
}

inline int find_func(const std::string& name) {
    for (int i = 0; i < (int)FUNC_DEFS.size(); i++)
        if (name == FUNC_DEFS[i].name) return i;
    return -1;
}
