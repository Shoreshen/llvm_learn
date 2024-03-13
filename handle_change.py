import os
import subprocess
import shutil
import sys

destination_dir = './cpu0/changes/'
new_files_dir = './cpu0/changes/new_files_dir'

def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
    output, error = process.communicate()

    if error:
        print(f"Error: {error}")
        exit(1)

    return output.decode('utf-8').strip()

def save_new():
    # 获取所有未跟踪的文件
    output = run_command("cd llvm-project/ && git status --short | grep '^??' | awk '{printf \"%s \", $2}'")
    files = output.split(' ')

    # 创建目标目录，如果它不存在
    os.makedirs(destination_dir, exist_ok=True)

    with open(new_files_dir, 'w') as f:
        for file in files:
            if file:  # 防止空字符串
                # 复制文件
                shutil.move(os.path.join('llvm-project', file), destination_dir)
                # 将文件路径写入到文本文件中
                f.write(file + '\n')

    print(f"Output: {output}")

def save_modify():
    diff_output = run_command("cd llvm-project/ && git diff")
    if diff_output:
        print(diff_output)
        user_input = input("Do you want to overwrite /cpu0/changes/llvm-modify.patch? (y/n): ")
        if user_input.lower() == 'y':
            with open('cpu0/changes/llvm-modify.patch', 'w') as f:
                f.write(diff_output + '\n')
    else:
        print("No changes to save.")

def clear_modify():
    run_command("cd llvm-project/ && git reset --hard")

def save():
    save_new()
    save_modify()
    clear_modify()

def restore_new():
    with open(new_files_dir, 'r') as f:
        for line in f:
            file = line.strip()  # 去除行尾的换行符
            if file:  # 防止空字符串
                # 将文件从destination_dir复制回llvm-project目录
                shutil.move(os.path.join(destination_dir, os.path.basename(file)), os.path.join('llvm-project', file))

def restore_modify():
    run_command("cd llvm-project/ && git apply ../cpu0/changes/llvm-modify.patch")

def restore():
    restore_modify()
    restore_new()

def main(arg):
    if arg == 'save':
        save()
    elif arg == 'restore':
        restore()
    else:
        print(f"Invalid argument: {arg}. Expected 'save' or 'restore'.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py [save|restore]")
        exit(1)
    if sys.argv[1] == 'save':
        save()
    elif sys.argv[1] == 'restore':
        restore()
    else:
        print(f"Invalid argument: {arg}. Expected 'save' or 'restore'.")