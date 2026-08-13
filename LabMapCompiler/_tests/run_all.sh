#!/bin/bash
# 一键测试：语法 + 错误用例 + 全部现有地图回归
cd "$(dirname "$0")/.."
EXE=./LabMapCompiler.exe
pass=0; fail=0

echo "===== 语法综合测试 ====="
if $EXE "_tests/语法综合测试.txt" "_tests/语法综合测试.bin"; then pass=$((pass+1)); else fail=$((fail+1)); fi

echo
echo "===== 正向用例 ====="
for f in _tests/ok_*.txt; do
    out="_tests/$(basename "$f" .txt).bin"
    if $EXE "$f" "$out"; then echo "PASS: $f"; pass=$((pass+1)); else echo "FAIL: $f"; fail=$((fail+1)); fi
done

echo
echo "===== 错误用例（应全部编译失败）====="
for f in _tests/err/*.txt; do
    out="_tests/err/$(basename "$f" .txt).bin"
    if $EXE "$f" "$out" >/dev/null 2>&1; then
        echo "UNEXPECTED-PASS: $f"; fail=$((fail+1))
    else
        pass=$((pass+1))
    fi
done

echo
echo "===== 现有地图回归 ====="
reg=0; regfail=0
while IFS= read -r f; do
    name=$(echo "$f" | sed 's|[\\/]|_|g; s|\.txt$||')
    out="_tests/corpus/${name}.bin"
    if $EXE "$f" "$out" > "_tests/corpus/${name}.log" 2>&1; then
        grep -q "Constants ->" "_tests/corpus/${name}.log" && echo "  [常量] $(grep 'Constants ->' "_tests/corpus/${name}.log")"
        reg=$((reg+1))
    else
        echo "REGRESSION-FAIL: $f"
        grep -a "Line" "_tests/corpus/${name}.log" | head -5
        regfail=$((regfail+1))
    fi
done <<'EOF'
../datafiles/laboratory/baiguiyexing fixed/baiguiyexing.txt
../datafiles/laboratory/baiguiyexing fixed/轮台花园地图创意来着美食大战老鼠进化版.txt
../datafiles/laboratory/map_script_editor-V2.2.1/demo/spices_central_isle.txt
../datafiles/laboratory/water and fire 2nd hard fixed/water and fire 2nd hard.txt
../datafiles/laboratory/勇士金刚 fixed/勇士金刚.txt
地图脚本编辑工具/aaa.txt
地图脚本编辑工具/demo.txt
地图脚本编辑工具/frames/两阶段脚本.txt
地图脚本编辑工具/功能测试.txt
地图脚本编辑工具/定义测试.txt
地图脚本编辑工具/平台循环.txt
地图脚本编辑工具/开局限制.txt
地图脚本编辑工具/文本测试.txt
地图脚本编辑工具/杀敌奖励.txt
地图脚本编辑工具/杀敌惩罚.txt
地图脚本编辑工具/板块切换.txt
地图脚本编辑工具/水上防线.txt
地图脚本编辑工具/波次控制.txt
地图脚本编辑工具/障碍跑酷.txt
platform_demo.txt
water and fire 2nd hard.txt
EOF

echo "回归: $reg 通过, $regfail 失败"
echo
echo "===== 总计: $pass 通过, $fail 失败 ====="
exit $((fail + regfail))
