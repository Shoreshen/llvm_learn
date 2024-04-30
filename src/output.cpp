#include "output.h"
#include <iostream>
#include <fstream>

std::map<std::string, std::pair<std::string, std::string>> param_map;

using namespace llvm;

std::string escape_string(const std::string input) {
    std::string output;
    for (char c : input) {
        switch (c) {
            case '\n': output += "\\n"; break;   // 处理换行
            case '\t': output += "\\t"; break;   // 处理制表符
            case '\\': output += "\\\\"; break;  // 处理反斜杠
            case '\r': output += "\\r"; break;   // 处理回车
            case '\"': output += "\\\""; break;  // 处理双引号
            case '\'': output += "\\'"; break;   // 处理单引号
            default: output += c; break;         // 其他字符直接添加
        }
    }
    return output;
}

void write_map_to_file(std::string file_name) 
{
    std::ofstream file(file_name);
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing.\n";
        return;
    }

    for (const auto& entry : param_map) {
        file << entry.first << "|\"" << escape_string(entry.second.first) << "\"|" << entry.second.second << "\n";
    }

    file.close();
}

void write_mod_to_file(Module* mod, std::string file_name) 
{
    // 创建一个文件流来写入.ll文件
    std::error_code EC;
    raw_fd_ostream OS(file_name.c_str(), EC);

    if (EC) {
        errs() << "Error opening file " << file_name.c_str() << " for writing!\n";
        exit(1);
    }

    // 打印module到文件
    mod->print(OS, nullptr);

    // 关闭文件流
    OS.flush();
}

void write_file(Module* mod, std::string map_file, std::string ll_file)
{
    write_map_to_file(map_file);
    write_mod_to_file(mod, ll_file);
}