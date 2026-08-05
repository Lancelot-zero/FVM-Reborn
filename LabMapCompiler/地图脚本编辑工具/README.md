# LabMapCompiler 使用手册

## 基本用法

```
LabMapCompiler.exe                       → 编译当前目录所有 .txt
LabMapCompiler.exe  脚本.txt              → 自动输出 脚本.bin
LabMapCompiler.exe  脚本.txt  输出.bin    → 指定输出文件
```

### 部署

1. 编译 `.txt` 脚本得到 `.bin` 文件
2. 把 `.bin` 放到 `C:\Users\你的用户名\AppData\Local\FVM_Reborn\laboratory\`
3. 确保同目录下有同名的 `.json` 地图文件
4. 进入对应实验室地图，`.bin` 自动加载
5. 修改脚本后只需替换 `.bin`，重新建房即可生效，无需重启游戏

## 编译期校验

编译器会校验函数调用的参数个数和类型，字符串参数还会检查值是否合法：

| 检查项 | 说明 |
|---|---|
| 参数个数 | 必须和函数签名一致（变长函数除外） |
| 参数类型 | int/float/string 不能混用 |
| 敌人ID | `VM_SpawnEnemy` / `VM_SpawnBoss` 的第1参必须在敌人列表中 |
| 卡片ID | `VM_SpawnPlant` / `VM_BanCard` 的第1参必须在卡片列表中 |
| 贴图前缀 | `VM_LoadSprite` 禁止 `spr_` 前缀 |

> 合法值列表参见 `compiler_defs.h` 中的 `VALID_ENEMY_IDS` / `VALID_CARD_IDS` / `VALID_OBJECT_NAMES`。

---

## 语法

### 变量 & 运算

```
x = 10
y = x + 5
z = x * y
ok = (x > y)
```

一行一句。支持 `+ - * / %` 和 `== != > >= < <=`。

可以定义不少于4096个变量。支持负数：`-1`。

> **注意**：函数参数不支持表达式，`VM_SetFlame(flame + 100)` 会丢失 `+ 100`。必须拆分：
> ```
> b = flame + 100
> VM_SetFlame(b)
> ```

**跨块变量**：在不同块中声明的同名变量共用同一个内存槽，可以用来跨事件传递状态。例如在 `_VM_BATTLE_START` 中 `a_cnt = 0`，在 `_VM_PLATFORM_IDLE_END` 中可以直接读写 `a_cnt`。

### 注释

```
// 这是注释
```

### 条件

```
if (wave == 0) {
    VM_ShowNotice("第一波")
}
if (wave == 3) {
    VM_SpawnBoss("arno", 2, 80000)
}
```

也支持 `else`：

```
if (a_cnt == 0) {
    VM_SetPlatformParams(a, 0, 2, 200, 1)
} else {
    VM_SetPlatformParams(a, 1, 2, 200, -1)
}
```

---

## 块（事件入口）

在块里写代码，游戏到对应时机自动执行。所有块都是可选的。

| 块名 | 说明 |
|---|---|
| `_VM_ROOM_READY_ENTRY` | 进入准备室（设规则） |
| `_VM_BATTLE_START` | 战斗开始（造地图） |
| `_VM_WAVE_START` | 新一波开始 |
| `_VM_WAVE_END` | 当前波结束 |
| `_VM_SUBWAVE_START` | 新子波开始 |
| `_VM_SUBWAVE_END` | 子波结束 |
| `_VM_CARD_CREATED` | 卡片被种下 |
| `_VM_CARD_DESTROYED` | 卡片被销毁 |
| `_VM_ENEMY_SPAWNED` | 敌人出现 |
| `_VM_ENEMY_KILLED` | 敌人死亡 |
| `_VM_PLATFORM_IDLE_END` | 平台 idle 结束，即将开始移动 |
| `_VM_FRAME` | ⚠️ 每帧执行，**禁止写复杂逻辑**（加血、刷怪等）。仅用于简单高频操作如更新 UI 绘制槽 |

---

## 全部函数

### 规则设置

| 函数 | 说明 |
|---|---|
| `VM_BanCard("卡名")` | 禁用某张卡 |
| `VM_SetCardLevelCap(等级)` | 卡片最高等级 |
| `VM_SetMaxSlots(数量)` | 最多带几张卡 |

### 地图

| 函数 | 说明 |
|---|---|
| `VM_SetTerrain(列, 行, "类型")` | 设地形，-1=全部。类型：`"normal"` `"water"` `"obstacle"` |
| `VM_ClearPlants(列, 行)` | 清除格子上的植物，-1=全部 |

### 创建

| 函数 | 说明 |
|---|---|
| `VM_CreatePlatform(列,行,宽,高,轴向,距离,停顿帧,贴图)` | 创建移动平台。轴向 0=上下 1=左右 |
| | 例: `a = VM_CreatePlatform(0, 0, 4, 5, 0, 2, 480, "spr_raft")` |
| `VM_SpawnPlant("卡名",列,行,外形,星级,技能)` | 种卡 |
| | 例: `VM_SpawnPlant("small_fire", 1, 1, 0, 10, 0)` |
| `VM_SpawnEnemy("敌人类型",行,血量)` | 刷敌人 |
| | 例: `VM_SpawnEnemy("normal_mouse", 2, 200)` |
| `VM_SpawnBoss("BOSS类型",行,血量)` | 刷BOSS |
| | 例: `VM_SpawnBoss("arno", 2, 80000)` |
| `VM_SpawnObject("物件名",列,行)` | ⚠️ 测试中，暂勿使用。刷障碍物/熔岩/风洞等 |

### 属性

| 函数 | 说明 |
|---|---|
| `VM_GetProp(实例ID, "属性名")` | 读实例属性 |
| `VM_SetProp(实例ID, "属性名", 值)` | 改实例属性，联机会同步 |

**平台常用属性：**

| 属性名 | 类型 | 说明 |
|---|---|---|
| `move_axis` | string | `"y"`=上下 `"x"`=左右 |
| `move_distance` | int | 移动距离（格） |
| `move_direction` | int | 1=正向 -1=反向 |
| `current_offset` | int | 当前偏移（格） |
| `boundary_idle_duration` | int | 边界停顿（帧） |
| `start_col` / `start_row` | int | 初始格子位置 |
| `width` / `length` | int | 平台尺寸（格） |

**敌人常用属性：**

| 属性名 | 类型 | 说明 |
|---|---|---|
| `hp` | int | 当前血量 |
| `maxhp` | int | 最大血量 |
| `speed` | float | 移动速度 |
| `state` | string | 当前状态 |

### 查询

| 函数 | 说明 |
|---|---|
| `VM_GetWave()` | 当前第几波 |
| `VM_GetSubwave()` | 当前第几子波 |
| `VM_GetFlame()` | 当前火苗数 |
| `VM_GetLastCreatedCard()` | 刚种的卡ID |
| `VM_GetLastDestroyedCard()` | 刚销毁的卡ID |
| `VM_GetLastCreatedEnemy()` | 刚刷的敌人ID |
| `VM_GetLastKilledEnemy()` | 刚死的敌人ID |
| `VM_GetLastBoss()` | 刚刷的BOSS ID |
| `VM_GetLastIdlePlatform()` | 刚结束 idle 的平台 ID |

### 工具

| 函数 | 说明 |
|---|---|
| `VM_Random(最小值, 最大值)` | 随机整数 |
| `VM_SetFlame(数量)` | 设置火苗数 |
| `VM_LoadSprite("贴图名")` | 加载贴图到内存，**禁止 `spr_` 前缀**（用 `s_spr_` 代替）。服务端从本地加载，客户端走网络懒加载 |
| `VM_SetMapBackground("贴图名", 步长)` | 渐变切换地图背景，步长控制过渡速度（如 0.02） |
| `VM_SetDrawSlot(槽位, "贴图名", x, y, alpha)` | 设置帧绘制槽。槽位 0~7，alpha 0~1，贴图名为空时清除。配合 `_VM_FRAME` 使用 |
| `VM_SetDrawSlot_front(槽位, "贴图名", x, y, alpha)` | 同 `VM_SetDrawSlot`，但绘制在火焰UI层（depth=-900），显示在火焰UI后面 |
| `VM_ShellPrint(...)` | 控制台打印，可拼多个参数 |
| `VM_ShowNotice(...)` | 屏幕通知，可拼多个参数 |
| `VM_SetPlatformParams(实例,轴,距离,停顿,方向)` | 以当前位置为新起点，重设平台移动参数 |
| `VM_GameWin()` | 触发胜利。客户端跳过；服务端弹出胜利界面并广播 |
| `VM_GameLose()` | 触发失败。客户端跳过；服务端弹出失败界面并广播 |

---

## 完整示例：平台循环换轴

```
// ========== 准备室：规则设置 ==========
_VM_ROOM_READY_ENTRY {
    VM_BanCard("small_fire")
    VM_BanCard("large_fire")
    VM_BanCard("goblet_lamp")
    VM_SetCardLevelCap(10)
    VM_SetMaxSlots(10)
}

// ========== 战斗开始：造地图 ==========
_VM_BATTLE_START {
    VM_ClearPlants(-1, -1)
    VM_SetTerrain(-1, -1, "obstacle")             // 全图不可种植，只有平台上是 normal
    VM_SetFlame(3000)

    // ---- 平台 A：大平台 (0,0) 4x5，由 hook 控制移动 ----
    // 首帧 idle=0 立即触发 hook，此后每步按计数器循环换轴
    a_cnt = 0
    a = VM_CreatePlatform(0, 0, 4, 5, 0, 0, 0, "spr_fennel_raft_platform_daytime")

    // ---- 平台 b1~b4：4个左右小平台，普通来回移动 ----
    b1 = VM_CreatePlatform(6, 0, 5, 1, 1, 1, 480, "spr_lilac_rainbow_platform_night_1")
    b2 = VM_CreatePlatform(6, 1, 5, 1, 1, 2, 480, "spr_lilac_rainbow_platform_night_2")
    b3 = VM_CreatePlatform(6, 5, 5, 1, 1, 2, 480, "spr_lilac_rainbow_platform_night_6")
    b4 = VM_CreatePlatform(6, 6, 5, 1, 1, 1, 480, "spr_lilac_rainbow_platform_night_7")
}

// ========== 平台 idle 结束：a 平台计数器取模换参数 ==========
// 触发时机：平台在边界停够 idle 帧后，即将开始移动前
// a 平台 4 步一个循环：下→右→上→左
_VM_PLATFORM_IDLE_END {
    if (VM_GetLastIdlePlatform() == a) {
        if (a_cnt == 0) {
            VM_SetPlatformParams(a, 0, 2, 200, 1)    // 上下，正向（下）
        }
        if (a_cnt == 1) {
            VM_SetPlatformParams(a, 1, 2, 200, 1)    // 左右，正向（右）
        }
        if (a_cnt == 2) {
            VM_SetPlatformParams(a, 0, 2, 200, -1)   // 上下，反向（上）
        }
        if (a_cnt == 3) {
            VM_SetPlatformParams(a, 1, 2, 200, -1)   // 左右，反向（左）
        }
        a_cnt = (a_cnt + 1) % 4     // 0→1→2→3→0...
    }
}
```

---

## 参数校验附录

编译期校验覆盖以下函数的字符串参数，必须使用合法值。

### 敌人 ID（VM_SpawnEnemy / VM_SpawnBoss）— 109 个

```
normal_mouse  football_fan_mouse  iron_pan_mouse  skateboard_mouse
landlady_mouse  zombie_with_flower_pot  machine_mouse  ninja_mouse
minion_mouse  kangaroo  repairman_mouse  diver_mouse  paper_boat_mouse
duck_mouse  tropical_fish_mouse  lambo_mouse  butterfly_mouse
taro_toho_mouse  water_taro_toho_mouse  assault_mouse  frog_prince_mouse
roller_skating_mouse  giant_mouse  mario_mouse  arno  temple_pharaoh
engineering_vehicle_mouse  garbage_track_mouse  mole  glider_mouse
ice_residue  bat_mouse  rumble  abyss_pharaoh  cucumber_paper_boat_mouse
apple_duck_mouse  egg_tropical_fish_mouse  orange_prince_mouse
submarine_mouse  rowboat_mouse  water_penguin_mouse  pink_paul
cucumber_normal_mouse  apple_football_fan_mouse  egg_iron_pan_mouse
tangerine_skateboard_mouse  shy_landlady_mouse  zombie_with_wallnut
caribbean_mouse  penguin_mouse  arson_mouse  non_mainstream_mouse
flute_mouse  panda_mouse  can_mouse  blonde_mary  pete
dragon_boat_mouse  flagship_mouse  thug_submarine_mouse
kof_submarine_mouse  soar_mouse  jet_mouse  dentist_mouse
sawblade_mouse  warrior_mouse  naruto_mouse  hazelnut_cannon_mouse
landmine_vehicle_mouse  waste_flying_mouse  airbrone_explosive_mouse
priest_mouse  pope_mouse  wrestler_mouse  special_armour_mouse
magician_mouse  ghost_mouse  flight_barrier_mouse  hells_messenger
needle_baron  fog_julie  lieutenant_buzz  paratrooper_mouse
irritable_jack  hot_vajra  machine_normal_mouse  machine_football_fan_mouse
machine_iron_pan_mouse  machine_skateboard_mouse  machine_flag_mouse
mirror_mouse  trumpeter_mouse  huang_xiaoming  angelababy
mouse_train_1  soldier_mouse  machine_bomb_mouse  aircraft_carrier
kamikaze_glider_mouse  captain_america_mouse  iron_man_mouse
mouse_train_2  charge_spring_mouse  snail_mouse  machine_beehive_mouse
machine_bee  spider_man_mouse  hulk_mouse  mouse_train_3
```

### 卡片 ID（VM_SpawnPlant / VM_BanCard）— 71 个

```
xiao_long_bao  small_fire  toast_bread  flour_sack  double_long_bao
mouse_clip  coke_bomb  wooden_plate  ice_long_bao  goblet_lamp
coffee_cup  salad_pult  coffee_pot  chocolate_bread  water_tea_cup
ice_bucket_bomb  stinky_tofu_pult  cat_box  kettle_bomb  triple_wine_rack
brazier  large_fire  iron_fishbone  gatlin_long_bao  rotating_coffee_pot
takoyaki  wooden_cork  coffee_grounds  wine_bottle_bomb  double_water_pipe
melon_shield  steel_wool  sausage  fishbone  hamburger  oil_lamp
ventilation_fan  egg_boiler_pult  ice_egg_boiler_pult  chocolate_pult
chocolate_cannon  firework_dragon  double_ice_long_bao  cat_chest
cherry_pudding  skewer_bomb  gatlin_ice_long_bao  aquarius_elve
tar_sprayer  triple_long_bao  triple_ice_long_bao  hotdog_cannon
oden_pot  whisky_bomb  cotton_candy  durian  dragon_fruit
pineapple_explosive_bread  ice_cream  lightning_baguette  bull_firework
magic_chicken  xinjiang_fried_noodles  king_long_bao  king_triple_long_bao
chili_powder  tang_hu_lu  beef_hotpot  spicy_pot  pan_fried_bun
```

### 物件名（VM_SpawnObject）— 9 个

```
obj_obstacle  obj_lava  obj_wind_tunnel  obj_mouse_hole
obj_pharaoh_hole  obj_buzz_wind  obj_cloud  obj_ladder
```

