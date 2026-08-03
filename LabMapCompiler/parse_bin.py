import struct
import sys

# opcodes
OP = {
    1: "ASSIGN", 2: "COPY",
    3: "ADD", 4: "SUB", 5: "MUL", 6: "DIV", 7: "MOD",
    8: "EQ", 9: "NEQ", 10: "GT", 11: "GTE", 12: "LT", 13: "LTE",
    14: "CALL", 15: "IF", 16: "JMP", 17: "HALT",
}

MEM = {0: "INT", 1: "FLOAT", 2: "STRING"}

def read_s32(data, off):
    return struct.unpack_from('<i', data, off)[0], off + 4

def read_u16(data, off):
    return struct.unpack_from('<H', data, off)[0], off + 2

def read_u8(data, off):
    return data[off], off + 1

def read_f32(data, off):
    return struct.unpack_from('<f', data, off)[0], off + 4


def parse_bin(path):
    with open(path, 'rb') as f:
        data = f.read()

    off = 0

    # ---- 字符串池 ----
    str_count, off = read_s32(data, off)
    strings = []
    for _ in range(str_count):
        slen, off = read_s32(data, off)
        s = data[off:off + slen].decode('utf-8', errors='replace')
        off += slen
        strings.append(s)

    print(f"=== 字符串池 ({str_count}个) ===")
    for i, s in enumerate(strings):
        print(f"  str_{i}: \"{s}\"")

    # ---- 块 ----
    block_num = 0
    while off < len(data):
        block_len, off = read_s32(data, off)
        name_idx, off = read_s32(data, off)
        name = strings[name_idx] if 0 <= name_idx < len(strings) else f"<out_of_range:{name_idx}>"

        print(f"\n=== Block \"{name}\" ({block_len} bytes) ===")

        end = off + block_len
        pos = 0  # buffer-relative position for jump targets
        bytecode = data[off:end]

        while off < end:
            pos = off - (end - block_len)  # bytecode offset from block start
            op, off = read_u8(data, off)

            op_name = OP.get(op, f"UNKNOWN_{op}")
            indent = "  "

            if op == 1:  # ASSIGN dst type val
                dst, off = read_s32(data, off)
                t, off = read_u8(data, off)
                if t == 2:  # STRING
                    val, off = read_u16(data, off)
                    print(f"{indent}[{pos:04x}] ASSIGN var_{dst} = str_{val}")
                elif t == 1:  # FLOAT
                    val, off = read_f32(data, off)
                    print(f"{indent}[{pos:04x}] ASSIGN var_{dst} = {val}f")
                else:
                    val, off = read_s32(data, off)
                    print(f"{indent}[{pos:04x}] ASSIGN var_{dst} = {val}")

            elif op == 2:  # COPY dst src
                dst, off = read_s32(data, off)
                src, off = read_s32(data, off)
                print(f"{indent}[{pos:04x}] COPY  var_{dst} = var_{src}")

            elif op in (3, 4, 5, 6, 7):  # ADD SUB MUL DIV MOD
                dst, off = read_s32(data, off)
                a, off = read_s32(data, off)
                b, off = read_s32(data, off)
                print(f"{indent}[{pos:04x}] {op_name}  var_{dst} = var_{a} {op_sym(op)} var_{b}")

            elif op in (8, 9, 10, 11, 12, 13):  # EQ NEQ GT GTE LT LTE
                dst, off = read_s32(data, off)
                a, off = read_s32(data, off)
                b, off = read_s32(data, off)
                print(f"{indent}[{pos:04x}] {op_name} var_{dst} = var_{a} {cmp_sym(op)} var_{b}")

            elif op == 14:  # CALL func_id arg_count dst [addr*]
                fid, off = read_u16(data, off)
                narg, off = read_u8(data, off)
                dst, off = read_s32(data, off)
                args = []
                for _ in range(narg):
                    a, off = read_s32(data, off)
                    args.append(f"var_{a}")
                dst_str = "void" if dst == -1 else f"var_{dst}"
                print(f"{indent}[{pos:04x}] CALL  func_{fid}({', '.join(args)}) -> {dst_str}")

            elif op == 15:  # IF cond true_ip false_ip
                cond, off = read_s32(data, off)
                tip, off = read_s32(data, off)
                fip, off = read_s32(data, off)
                print(f"{indent}[{pos:04x}] IF    var_{cond} ? goto {tip:04x} : goto {fip:04x}")

            elif op == 16:  # JMP ip
                ip, off = read_s32(data, off)
                print(f"{indent}[{pos:04x}] JMP   goto {ip:04x}")

            elif op == 17:  # HALT
                print(f"{indent}[{pos:04x}] HALT")

            else:
                print(f"{indent}[{pos:04x}] ???   op={op}")
                break

        off = end
        block_num += 1


def op_sym(op):
    return {3: '+', 4: '-', 5: '*', 6: '/', 7: '%'}.get(op, '?')

def cmp_sym(op):
    return {8: '==', 9: '!=', 10: '>', 11: '>=', 12: '<', 13: '<='}.get(op, '?')


if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'water and fire 2nd hard.bin'
    parse_bin(path)
