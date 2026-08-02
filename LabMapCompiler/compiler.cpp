#include "compiler_defs.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <map>
#include <string>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <clocale>
#include <io.h>

using namespace std;

// UTF-8 → 系统编码（GBK）用于终端输出
static string utf8_to_local(const string& u8) {
    wchar_t wbuf[4096];
    int wi = 0;
    for (size_t i = 0; i < u8.size() && wi < 4095; ) {
        unsigned char c = u8[i]; unsigned int cp; int len;
        if (c < 0x80)      { cp = c; len = 1; }
        else if (c < 0xE0) { cp = ((c&0x1F)<<6) | (u8[i+1]&0x3F); len = 2; }
        else if (c < 0xF0) { cp = ((c&0x0F)<<12) | ((u8[i+1]&0x3F)<<6) | (u8[i+2]&0x3F); len = 3; }
        else               { cp = ((c&0x07)<<18) | ((u8[i+1]&0x3F)<<12) | ((u8[i+2]&0x3F)<<6) | (u8[i+3]&0x3F); len = 4; }
        wbuf[wi++] = (wchar_t)cp;
        i += len;
    }
    wbuf[wi] = 0;
    char mb[8192];
    wcstombs(mb, wbuf, 8192);
    return string(mb);
}

using namespace std;

// ============================================================
// Token 定义
// ============================================================
enum TokenType {
    TK_EOF,
    TK_IDENT,
    TK_INT,
    TK_FLOAT,
    TK_STRING,
    TK_LBRACE, TK_RBRACE,
    TK_LPAREN, TK_RPAREN,
    TK_ASSIGN, TK_COMMA,
    TK_PLUS, TK_MINUS, TK_STAR, TK_SLASH, TK_MOD,
    TK_GT, TK_LT, TK_EQ, TK_NEQ, TK_GTE, TK_LTE,
};

static const char* tk_name(TokenType t) {
    switch (t) {
        case TK_EOF: return "EOF";
        case TK_IDENT: return "标识符";
        case TK_INT: return "整数";
        case TK_FLOAT: return "浮点数";
        case TK_STRING: return "字符串";
        case TK_LBRACE: return "{"; case TK_RBRACE: return "}";
        case TK_LPAREN: return "("; case TK_RPAREN: return ")";
        case TK_ASSIGN: return "="; case TK_COMMA: return ",";
        case TK_PLUS: return "+"; case TK_MINUS: return "-";
        case TK_STAR: return "*"; case TK_SLASH: return "/";
        case TK_MOD: return "%";
        case TK_GT: return ">"; case TK_LT: return "<";
        case TK_EQ: return "=="; case TK_NEQ: return "!=";
        case TK_GTE: return ">="; case TK_LTE: return "<=";
        default: return "?";
    }
}

struct Token {
    TokenType type = TK_EOF;
    string str_val;
    int int_val = 0;
    float float_val = 0;
    int line = 0;
};

// ============================================================
// 字符串池
// ============================================================
struct StringPool {
    vector<string> strs;
    int add(const string& s) {
        for (int i = 0; i < (int)strs.size(); i++)
            if (strs[i] == s) return i;
        strs.push_back(s);
        return (int)strs.size() - 1;
    }
    int size() const { return (int)strs.size(); }
};

// ============================================================
// 变量表 — 所有变量分配内存槽位
// ============================================================
struct VarTable {
    map<string, int> name_to_slot;
    int next_slot = 0;

    int alloc(const string& name) {
        auto it = name_to_slot.find(name);
        if (it != name_to_slot.end()) return it->second;
        int s = next_slot++;
        name_to_slot[name] = s;
        return s;
    }
    int get(const string& name) const {
        auto it = name_to_slot.find(name);
        return (it != name_to_slot.end()) ? it->second : -1;
    }
    int count() const { return next_slot; }
};

// ============================================================
// ByteBuf — 指令缓冲区
// ============================================================
struct ByteBuf {
    vector<uint8_t> buf;
    void u8(uint8_t v)  { buf.push_back(v); }
    void u16(uint16_t v) {
        buf.push_back((uint8_t)(v & 0xFF));
        buf.push_back((uint8_t)((v >> 8) & 0xFF));
    }
    void s32(int32_t v) {
        buf.push_back((uint8_t)(v & 0xFF));
        buf.push_back((uint8_t)((v >> 8) & 0xFF));
        buf.push_back((uint8_t)((v >> 16) & 0xFF));
        buf.push_back((uint8_t)((v >> 24) & 0xFF));
    }
    int tell() const { return (int)buf.size(); }
    void patch_s32(int offset, int32_t val) {
        buf[offset]     = (uint8_t)(val & 0xFF);
        buf[offset + 1] = (uint8_t)((val >> 8) & 0xFF);
        buf[offset + 2] = (uint8_t)((val >> 16) & 0xFF);
        buf[offset + 3] = (uint8_t)((val >> 24) & 0xFF);
    }
};

// ============================================================
// 编译器
// ============================================================
class Compiler {
public:
    Compiler(const string& src) : src_(src) {}

    bool compile(string& err_msg) {
        // ---- 第一遍：收集 ----
        src_copy_ = src_;
        pos_ = 0; line_ = 1; next();
        if (!collect(err_msg)) return false;

        // ---- 第二遍：生成 ----
        pos_ = 0; line_ = 1; next();
        if (!generate()) return false;

        return true;
    }

    const StringPool& strings() const { return strings_; }
    const vector<pair<int, vector<uint8_t>>>& blocks() const { return blocks_; }

private:
    string src_;
    string src_copy_;
    int pos_ = 0;
    int line_ = 1;
    Token cur_;

    StringPool strings_;
    VarTable vars_;
    vector<pair<int, vector<uint8_t>>> blocks_;
    ByteBuf* cur_buf_ = nullptr;
    int temp_base_ = 0;        // 临时槽位起点（= 用户变量数）
    map<int, int> slot_type_;     // 槽位 → 类型 (MEM_INT/MEM_FLOAT/MEM_STRING)
    map<int, string> slot_str_;   // 槽位 → 字面量字符串值（仅字面量槽位有）

    void set_type(int slot, int t) { slot_type_[slot] = t; }
    int  get_type(int slot) { auto it = slot_type_.find(slot); return (it != slot_type_.end()) ? it->second : MEM_INT; }
    void set_str(int slot, const string& s) { slot_str_[slot] = s; }
    bool get_str(int slot, string& out) { auto it = slot_str_.find(slot); if (it != slot_str_.end()) { out = it->second; return true; } return false; }
    bool is_num(int t) { return t == MEM_INT || t == MEM_FLOAT; }
    int  infer_bin_type(int ta, int tb) {
        if (!is_num(ta) || !is_num(tb)) {
            cerr << "错误: 字符串不能参与算术运算" << endl;
            return MEM_INT;
        }
        return (ta == MEM_FLOAT || tb == MEM_FLOAT) ? MEM_FLOAT : MEM_INT;
    }

    // ========== Tokenizer ==========
    void skip_ws_comment() {
        while (pos_ < (int)src_copy_.size()) {
            char c = src_copy_[pos_];
            if (c == ' ' || c == '\t' || c == '\r') { pos_++; continue; }
            if (c == '\n') { pos_++; line_++; continue; }
            if (c == '#' || (c == '/' && pos_ + 1 < (int)src_copy_.size() && src_copy_[pos_ + 1] == '/')) {
                while (pos_ < (int)src_copy_.size() && src_copy_[pos_] != '\n') pos_++;
                continue;
            }
            break;
        }
    }

    Token read_token() {
        skip_ws_comment();
        Token t;
        t.line = line_;
        if (pos_ >= (int)src_copy_.size()) { t.type = TK_EOF; return t; }

        char c = src_copy_[pos_];

        if (c >= '0' && c <= '9') {
            int start = pos_;
            while (pos_ < (int)src_copy_.size() && src_copy_[pos_] >= '0' && src_copy_[pos_] <= '9') pos_++;
            if (pos_ < (int)src_copy_.size() && src_copy_[pos_] == '.') {
                pos_++;
                while (pos_ < (int)src_copy_.size() && src_copy_[pos_] >= '0' && src_copy_[pos_] <= '9') pos_++;
                t.type = TK_FLOAT;
                t.float_val = (float)atof(src_copy_.substr(start, pos_ - start).c_str());
            } else {
                t.type = TK_INT;
                t.int_val = atoi(src_copy_.substr(start, pos_ - start).c_str());
            }
            return t;
        }

        if (c == '"') {
            pos_++;
            string s;
            while (pos_ < (int)src_copy_.size() && src_copy_[pos_] != '"') {
                if (src_copy_[pos_] == '\\' && pos_ + 1 < (int)src_copy_.size()) {
                    pos_++;
                    char esc = src_copy_[pos_];
                    if (esc == 'n') s += '\n';
                    else if (esc == 't') s += '\t';
                    else if (esc == '"') s += '"';
                    else if (esc == '\\') s += '\\';
                    else { s += '\\'; s += esc; }
                } else {
                    s += src_copy_[pos_];
                }
                pos_++;
            }
            if (pos_ < (int)src_copy_.size()) pos_++;
            t.type = TK_STRING;
            t.str_val = s;
            return t;
        }

        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (c & 0x80)) {
            int start = pos_;
            while (pos_ < (int)src_copy_.size()) {
                char ch = src_copy_[pos_];
                if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                    (ch >= '0' && ch <= '9') || ch == '_' || (ch & 0x80)) pos_++;
                else break;
            }
            t.type = TK_IDENT;
            t.str_val = src_copy_.substr(start, pos_ - start);
            return t;
        }

        pos_++;
        switch (c) {
            case '{': t.type = TK_LBRACE;  return t;
            case '}': t.type = TK_RBRACE;  return t;
            case '(': t.type = TK_LPAREN;  return t;
            case ')': t.type = TK_RPAREN;  return t;
            case '=':
                if (pos_ < (int)src_copy_.size() && src_copy_[pos_] == '=') { pos_++; t.type = TK_EQ; }
                else t.type = TK_ASSIGN;
                return t;
            case ',': t.type = TK_COMMA;  return t;
            case '+': t.type = TK_PLUS;   return t;
            case '-': t.type = TK_MINUS;  return t;
            case '*': t.type = TK_STAR;   return t;
            case '/':
                if (pos_ < (int)src_copy_.size() && src_copy_[pos_] == '/') {
                    while (pos_ < (int)src_copy_.size() && src_copy_[pos_] != '\n') pos_++;
                    return read_token();
                }
                t.type = TK_SLASH;
                return t;
            case '%': t.type = TK_MOD;    return t;
            case '>':
                if (pos_ < (int)src_copy_.size() && src_copy_[pos_] == '=') { pos_++; t.type = TK_GTE; }
                else t.type = TK_GT;
                return t;
            case '<':
                if (pos_ < (int)src_copy_.size() && src_copy_[pos_] == '=') { pos_++; t.type = TK_LTE; }
                else t.type = TK_LT;
                return t;
            case '!':
                if (pos_ < (int)src_copy_.size() && src_copy_[pos_] == '=') { pos_++; t.type = TK_NEQ; }
                else t.type = TK_EOF;
                return t;
            default:
                t.type = TK_EOF;
                return t;
        }
    }

    Token next() { Token t = cur_; cur_ = read_token(); return t; }
    bool check(TokenType t) { return cur_.type == t; }
    bool match(TokenType t) { if (check(t)) { next(); return true; } return false; }
    Token expect(TokenType t, string& err) {
        if (cur_.type != t) {
            err = "第" + to_string(cur_.line) + "行: 期望 " + tk_name(t) + ", 遇到 " + tk_name(cur_.type);
            return cur_;
        }
        return next();
    }

    // ========== 临时槽位管理 ==========
    int alloc_temp() {
        return temp_base_++;
    }

    // ========== 指令发射 ==========
    void emit_bin_op(int op, int dst, int a, int b) {
        cur_buf_->u8(op);
        cur_buf_->s32(dst);
        cur_buf_->s32(a);
        cur_buf_->s32(b);
    }

    void emit_call(int func_id, const vector<int>& args, int dst) {
        cur_buf_->u8(OP_CALL);
        cur_buf_->u16((uint16_t)func_id);
        cur_buf_->u8((uint8_t)args.size());
        cur_buf_->s32(dst);
        for (int a : args) {
            cur_buf_->s32(a);
        }
    }

    // ========== 参数校验 ==========
    void check_call_args(int func_id, const vector<int>& args) {
        auto& def = FUNC_DEFS[func_id];
        int expected = def.param_count;

        // 变长函数不校验
        if (expected < 0) return;

        // 校验参数个数
        if ((int)args.size() != expected) {
            cerr << "第" << cur_.line << "行: " << def.name
                 << " 期望 " << expected << " 个参数，实际传入 "
                 << args.size() << " 个" << endl;
            return;
        }

        // 校验每个参数类型
        if (expected == 0) return;
        auto& ptypes = def.param_types;
        for (int i = 0; i < expected; i++) {
            int expect_t = (i < (int)ptypes.size()) ? ptypes[i] : PT_INT;
            if (expect_t == PT_ANY) continue;
            int actual_t = get_type(args[i]);
            if (actual_t != expect_t) {
                cerr << "第" << cur_.line << "行: " << def.name
                     << " 第" << (i + 1) << " 个参数期望 "
                     << param_type_name(expect_t) << "，实际是 "
                     << param_type_name(actual_t) << endl;
                continue;
            }
            // 字符串参数：校验字面量值是否在合法集合中
            if (expect_t == PT_STRING) {
                string sval;
                if (!get_str(args[i], sval)) continue;
                const vector<const char*>* pset = nullptr;
                switch (func_id) {
                    case 0:                    // VM_BanCard → 卡片ID
                    case 6:  pset = &VALID_CARD_IDS; break;   // VM_SpawnPlant
                    case 7:                     // VM_SpawnEnemy
                    case 8:  pset = &VALID_ENEMY_IDS; break;  // VM_SpawnBoss
                    case 10: pset = &VALID_OBJECT_NAMES; break; // VM_SpawnObject
                }
                if (pset && !str_in_set(sval, *pset)) {
                    cerr << "第" << cur_.line << "行: " << def.name
                         << " 第" << (i + 1) << " 个参数 \"" << sval
                         << "\" 不是合法值" << endl;
                }
                // VM_LoadSprite 外部加载禁止 spr_ 前缀
                if (func_id == 9 && sval.size() >= 4 && sval.substr(0, 4) == "spr_") {
                    cerr << "第" << cur_.line << "行: VM_LoadSprite 禁止 spr_ 前缀，请用外部图片文件" << endl;
                }
            }
        }
    }

    // ====================================================================
    // 第一遍：收集字符串 & 变量，校验块名/函数名
    // ====================================================================
    bool collect(string& err) {
        while (!check(TK_EOF)) {
            if (check(TK_RBRACE)) { next(); continue; }
            if (check(TK_IDENT)) {
                if (!collect_ident(err)) return false;
                continue;
            }
            next();
        }
        return true;
    }

    bool collect_ident(string& err) {
        string name = cur_.str_val;

        int bi = find_block(name);
        if (bi >= 0) {
            strings_.add(name);
            next();
            if (!match(TK_LBRACE)) { err = "第" + to_string(cur_.line) + "行: 块名后需要 {"; return false; }
            return true;
        }

        if (name == "halt") { next(); return true; }

        if (name == "else") { next(); match(TK_LBRACE); return true; }

        if (name == "if") {
            next();
            match(TK_LPAREN);
            collect_expr();
            match(TK_RPAREN);
            match(TK_LBRACE);
            while (!check(TK_RBRACE) && !check(TK_EOF)) {
                if (check(TK_IDENT)) collect_ident(err);
                else next();
            }
            match(TK_RBRACE);
            if (check(TK_IDENT) && cur_.str_val == "else") {
                next();
                match(TK_LBRACE);
                while (!check(TK_RBRACE) && !check(TK_EOF)) {
                    if (check(TK_IDENT)) collect_ident(err);
                    else next();
                }
                match(TK_RBRACE);
            }
            return true;
        }

        // 赋值 / 函数调用
        next();
        if (check(TK_LPAREN)) {
            int fi = find_func(name);
            if (fi < 0) { err = "第" + to_string(cur_.line) + "行: 未知函数名 " + name; return false; }
            next();
            collect_args();
            if (!match(TK_RPAREN)) { err = "第" + to_string(cur_.line) + "行: 缺少 )"; return false; }
        } else if (check(TK_ASSIGN)) {
            if (find_block(name) >= 0) { err = "第" + to_string(cur_.line) + "行: 不能给块名赋值"; return false; }
            if (find_func(name) >= 0) { err = "第" + to_string(cur_.line) + "行: 不能给函数名赋值"; return false; }
            if (name == "if" || name == "else" || name == "halt") { err = "第" + to_string(cur_.line) + "行: 关键字"; return false; }
            vars_.alloc(name);
            next();
            collect_expr();
        }
        return true;
    }

    void collect_expr() {
        int start_line = cur_.line;
        int depth = 0;
        while (!check(TK_EOF)) {
            TokenType t = cur_.type;
            if (t == TK_LBRACE || t == TK_RBRACE) break;
            if (cur_.line != start_line) break;
            if (t == TK_RPAREN && depth == 0) break;
            if (t == TK_COMMA && depth == 0) break;
            if (t == TK_LPAREN) depth++;
            if (t == TK_RPAREN) { depth--; if (depth < 0) break; }

            if (t == TK_STRING) {
                strings_.add(cur_.str_val);
            } else if (t == TK_IDENT) {
                string name = cur_.str_val;
                if (find_func(name) < 0 && find_block(name) < 0 &&
                    name != "if" && name != "else" && name != "halt") {
                    vars_.alloc(name);
                }
            }
            next();
        }
    }

    void collect_args() {
        while (!check(TK_RPAREN) && !check(TK_EOF)) {
            collect_expr();
            if (!match(TK_COMMA)) break;
        }
    }

    // ====================================================================
    // 第二遍：生成字节码
    // ====================================================================
    bool generate() {
        while (!check(TK_EOF)) {
            while (match(TK_RBRACE)) {}

            if (check(TK_EOF)) break;

            if (check(TK_IDENT)) {
                string name = cur_.str_val;
                int bi = find_block(name);
                if (bi >= 0) {
                    gen_block(bi);
                    continue;
                }
            }
            next();
        }
        return true;
    }

    void gen_block(int block_name_idx) {
        ByteBuf bb;
        cur_buf_ = &bb;
        temp_base_ = vars_.count();  // 临时槽位从用户变量之后开始

        next();                     // 块名
        match(TK_LBRACE);

        while (!check(TK_RBRACE) && !check(TK_EOF)) {
            gen_statement();
        }
        match(TK_RBRACE);

        int name_str_idx = strings_.add(BLOCK_NAMES[block_name_idx]);
        blocks_.push_back({name_str_idx, bb.buf});
        cur_buf_ = nullptr;
    }

    // ========== 语句 ==========
    void gen_statement() {
        if (check(TK_EOF) || check(TK_RBRACE)) return;

        if (check(TK_IDENT)) {
            string name = cur_.str_val;

            if (name == "halt") {
                next();
                cur_buf_->u8(OP_HALT);
                return;
            }
            if (name == "if") {
                gen_if();
                return;
            }
            if (name == "else") {
                return;
            }

            next();  // 吃掉标识符
            if (check(TK_ASSIGN)) {
                // 变量 = 表达式
                int var_slot = vars_.get(name);
                next();  // 吃掉 =
                int src_slot = gen_expr();
                if (src_slot != var_slot) {
                    cur_buf_->u8(OP_COPY);
                    cur_buf_->s32(var_slot);
                    cur_buf_->s32(src_slot);
                }
                set_type(var_slot, get_type(src_slot));
                return;
            }
            if (check(TK_LPAREN)) {
                // 函数调用（语句级，丢弃返回值）
                int fid = find_func(name);
                if (fid < 0) { next(); return; }
                next();  // 吃掉 (
                vector<int> args;
                gen_args(args);
                match(TK_RPAREN);
                check_call_args(fid, args);
                emit_call(fid, args, VOID_DST);
                return;
            }
            return;
        }
        next();
    }

    // ========== if ==========
    void gen_if() {
        next();                    // if
        match(TK_LPAREN);
        int cond_slot = gen_expr(); // 条件
        match(TK_RPAREN);

        cur_buf_->u8(OP_IF);
        cur_buf_->s32(cond_slot);
        int true_patch  = cur_buf_->tell(); cur_buf_->s32(0);
        int false_patch = cur_buf_->tell(); cur_buf_->s32(0);

        match(TK_LBRACE);
        int ip_true = cur_buf_->tell();
        while (!check(TK_RBRACE) && !check(TK_EOF)) gen_statement();
        match(TK_RBRACE);

        bool has_else = (check(TK_IDENT) && cur_.str_val == "else");
        int jmp_patch = -1;
        if (has_else) {
            cur_buf_->u8(OP_JMP);
            jmp_patch = cur_buf_->tell();
            cur_buf_->s32(0);
        }

        int ip_false;
        if (has_else) {
            next();  // else
            match(TK_LBRACE);
            ip_false = cur_buf_->tell();
            while (!check(TK_RBRACE) && !check(TK_EOF)) gen_statement();
            match(TK_RBRACE);
        } else {
            ip_false = cur_buf_->tell();
        }

        int ip_after = cur_buf_->tell();

        cur_buf_->patch_s32(true_patch, ip_true);
        cur_buf_->patch_s32(false_patch, ip_false);
        if (jmp_patch >= 0) {
            cur_buf_->patch_s32(jmp_patch, ip_after);
        }
    }

    // ========== 表达式 — 返回结果槽位 ==========
    int gen_expr()  { return gen_cmp(); }

    // 比较
    int gen_cmp() {
        int left = gen_add();
        while (true) {
            int op = -1;
            if (check(TK_EQ))  op = OP_EQ;
            else if (check(TK_NEQ)) op = OP_NEQ;
            else if (check(TK_GT))  op = OP_GT;
            else if (check(TK_GTE)) op = OP_GTE;
            else if (check(TK_LT))  op = OP_LT;
            else if (check(TK_LTE)) op = OP_LTE;
            else break;

            next();
            int right = gen_add();
            get_type(left); get_type(right);  // 类型校验（比较允许跨类型）
            int temp = alloc_temp();
            set_type(temp, MEM_INT);  // 比较结果总是 int
            emit_bin_op(op, temp, left, right);
            left = temp;
        }
        return left;
    }

    // 加减
    int gen_add() {
        int left = gen_mul();
        while (check(TK_PLUS) || check(TK_MINUS)) {
            int op = check(TK_PLUS) ? OP_ADD : OP_SUB;
            next();
            int right = gen_mul();
            int t = infer_bin_type(get_type(left), get_type(right));
            int temp = alloc_temp();
            set_type(temp, t);
            emit_bin_op(op, temp, left, right);
            left = temp;
        }
        return left;
    }

    // 乘除模
    int gen_mul() {
        int left = gen_primary();
        while (check(TK_STAR) || check(TK_SLASH) || check(TK_MOD)) {
            int op = 0;
            if (check(TK_STAR)) op = OP_MUL;
            else if (check(TK_SLASH)) op = OP_DIV;
            else op = OP_MOD;
            next();
            int right = gen_primary();
            int t = (op == OP_MOD) ? MEM_INT : infer_bin_type(get_type(left), get_type(right));
            int temp = alloc_temp();
            set_type(temp, t);
            emit_bin_op(op, temp, left, right);
            left = temp;
        }
        return left;
    }

    // 基础项：返回结果所在的内存槽位
    int gen_primary() {
        // 一元负号: -5 → 0-5
        if (check(TK_MINUS)) {
            next();
            int zero = alloc_temp(); set_type(zero, MEM_INT);
            cur_buf_->u8(OP_ASSIGN); cur_buf_->s32(zero); cur_buf_->u8(MEM_INT); cur_buf_->s32(0);
            int right = gen_primary();
            int t = alloc_temp(); set_type(t, get_type(right));
            emit_bin_op(OP_SUB, t, zero, right);
            return t;
        }
        if (check(TK_INT)) {
            int val = cur_.int_val;
            next();
            int t = alloc_temp();
            set_type(t, MEM_INT);
            cur_buf_->u8(OP_ASSIGN);
            cur_buf_->s32(t);
            cur_buf_->u8(MEM_INT);
            cur_buf_->s32(val);
            return t;
        }
        if (check(TK_FLOAT)) {
            float val = cur_.float_val;
            next();
            int t = alloc_temp();
            set_type(t, MEM_FLOAT);
            int bits; memcpy(&bits, &val, 4);
            cur_buf_->u8(OP_ASSIGN);
            cur_buf_->s32(t);
            cur_buf_->u8(MEM_FLOAT);
            cur_buf_->s32(bits);
            return t;
        }
        if (check(TK_STRING)) {
            string str_val = cur_.str_val;
            int si = strings_.add(str_val);
            next();
            int t = alloc_temp();
            set_type(t, MEM_STRING);
            set_str(t, str_val);
            cur_buf_->u8(OP_ASSIGN);
            cur_buf_->s32(t);
            cur_buf_->u8(MEM_STRING);
            cur_buf_->u16((uint16_t)si);
            return t;
        }
        if (check(TK_IDENT)) {
            string name = cur_.str_val;
            int fi = find_func(name);
            if (fi >= 0) {
                // 函数调用 → 返回值放临时槽
                next();
                match(TK_LPAREN);
                vector<int> args;
                gen_args(args);
                match(TK_RPAREN);
                check_call_args(fi, args);
                int t = alloc_temp();
                emit_call(fi, args, t);
                return t;
            }
            // 变量 → 直接返回其槽位
            int slot = vars_.get(name);
            if (slot < 0) { next(); return alloc_temp(); }  // 容错
            next();
            return slot;
        }
        if (match(TK_LPAREN)) {
            int result = gen_expr();
            string err; expect(TK_RPAREN, err);
            return result;
        }
        next();
        return alloc_temp();
    }

    // ========== 参数列表 — 收集内存地址 ==========
    void gen_args(vector<int>& args) {
        while (!check(TK_RPAREN) && !check(TK_EOF)) {
            // 处理负数: -5 → 0-5 的临时结果
            if (check(TK_MINUS)) {
                next(); // 吃掉 -
                if (check(TK_INT)) {
                    int val = -cur_.int_val;
                    next();
                    int t = alloc_temp();
                    set_type(t, MEM_INT);
                    cur_buf_->u8(OP_ASSIGN); cur_buf_->s32(t); cur_buf_->u8(MEM_INT); cur_buf_->s32(val);
                    args.push_back(t);
                } else if (check(TK_FLOAT)) {
                    float v = -cur_.float_val; next();
                    int t = alloc_temp(); set_type(t, MEM_FLOAT);
                    int bits; memcpy(&bits, &v, 4);
                    cur_buf_->u8(OP_ASSIGN); cur_buf_->s32(t); cur_buf_->u8(MEM_FLOAT); cur_buf_->s32(bits);
                    args.push_back(t);
                }
                if (!match(TK_COMMA)) break;
                continue;
            }
            if (check(TK_INT)) {
                int val = cur_.int_val;
                next();
                int t = alloc_temp();
                set_type(t, MEM_INT);
                cur_buf_->u8(OP_ASSIGN);
                cur_buf_->s32(t);
                cur_buf_->u8(MEM_INT);
                cur_buf_->s32(val);
                args.push_back(t);
            } else if (check(TK_FLOAT)) {
                float val = cur_.float_val;
                next();
                int t = alloc_temp();
                set_type(t, MEM_FLOAT);
                int bits; memcpy(&bits, &val, 4);
                cur_buf_->u8(OP_ASSIGN);
                cur_buf_->s32(t);
                cur_buf_->u8(MEM_FLOAT);
                cur_buf_->s32(bits);
                args.push_back(t);
            } else if (check(TK_STRING)) {
                string str_val = cur_.str_val;
                int si = strings_.add(str_val);
                next();
                int t = alloc_temp();
                set_type(t, MEM_STRING);
                set_str(t, str_val);
                cur_buf_->u8(OP_ASSIGN);
                cur_buf_->s32(t);
                cur_buf_->u8(MEM_STRING);
                cur_buf_->u16((uint16_t)si);
                args.push_back(t);
            } else if (check(TK_IDENT)) {
                int slot = vars_.get(cur_.str_val);
                if (slot >= 0) {
                    args.push_back(slot);
                    next();
                } else {
                    // 可能是函数调用表达式，先求值
                    cerr << "第" << cur_.line << "行: 参数不支持复杂表达式，请先赋给变量" << endl;
                    next();
                }
            } else {
                next();
            }
            if (!match(TK_COMMA)) break;
        }
    }

};

// ============================================================
// 二进制写入
// ============================================================
void write_binary(const string& path, const StringPool& strings,
                  const vector<pair<int, vector<uint8_t>>>& blocks) {
    ofstream out(path, ios::binary);
    if (!out) { cerr << "Error: 无法写入文件 " << path << endl; return; }

    auto w_int = [&](int32_t v) {
        out.put((char)(v & 0xFF));
        out.put((char)((v >> 8) & 0xFF));
        out.put((char)((v >> 16) & 0xFF));
        out.put((char)((v >> 24) & 0xFF));
    };

    // 字符串池
    w_int(strings.size());
    for (int i = 0; i < strings.size(); i++) {
        const string& s = strings.strs[i];
        w_int((int32_t)s.size());
        out.write(s.c_str(), s.size());
    }

    // 块数据
    for (auto& blk : blocks) {
        int32_t bytecode_len = (int32_t)blk.second.size();
        w_int(bytecode_len);
        w_int(blk.first);
        out.write((const char*)blk.second.data(), blk.second.size());
    }

    out.close();
    cout << utf8_to_local("编译成功: ") << path << " (" << blocks.size() << utf8_to_local(" 个块, ")
         << strings.size() << utf8_to_local(" 个字符串)") << endl;
}

// ============================================================
// 辅助
// ============================================================
static string derive_output(const string& input) {
    size_t pos = input.rfind(".txt");
    if (pos != string::npos && pos == input.size() - 4)
        return input.substr(0, pos) + ".bin";
    return input + ".bin";
}

static int compile_one(const string& src_path, const string& out_path) {
    ifstream in(src_path);
    if (!in) {
        cerr << "Error: 无法读取 " << src_path << endl;
        return 1;
    }
    stringstream ss;
    ss << in.rdbuf();
    string src = ss.str();
    in.close();
    Compiler compiler(src);
    string err;
    if (!compiler.compile(err)) {
        cerr << "编译错误 (" << src_path << "): " << err << endl;
        return 1;
    }
    write_binary(out_path, compiler.strings(), compiler.blocks());
    return 0;
}

// ============================================================
// 入口
// ============================================================
int main(int argc, char* argv[]) {
    setlocale(LC_ALL, "");

    // ---- 无参数：遍历当前目录下所有 .txt ----
    if (argc < 2) {
        int total = 0, ok = 0;
        _finddata_t fd;
        intptr_t hFind = _findfirst("*.txt", &fd);
        if (hFind != -1) {
            do {
                string name = fd.name;
                string out = derive_output(name);
                cout << utf8_to_local("编译: ") << name << " -> " << out << endl;
                int ret = compile_one(name, out);
                if (ret == 0) ok++;
                total++;
            } while (_findnext(hFind, &fd) == 0);
            _findclose(hFind);
        }
        if (total == 0) {
            cerr << utf8_to_local("当前目录没有 .txt 文件") << endl;
            return 1;
        }
        cout << utf8_to_local("完成: ") << ok << "/" << total << utf8_to_local(" 个文件") << endl;
        return (ok == total) ? 0 : 1;
    }

    // ---- 1 或 2 个参数 ----
    string in_path = argv[1];
    string out_path = (argc >= 3) ? argv[2] : derive_output(in_path);
    return compile_one(in_path, out_path);
}
