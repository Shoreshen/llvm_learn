# $@  表示目标文件
# $^  表示所有的依赖文件
# $<  表示第一个依赖文件
# $?  表示比目标还要新的依赖文件列表
LLVM_NEW_FILES = $(shell cd llvm-project; git status --short | grep '^??' | awk '{printf "%s ", $$2}')
BRANCH = $(shell git symbolic-ref --short HEAD)
# git ====================================================================================
sub_pull:
	git submodule foreach --recursive 'git pull'
commit: clean
	git add -A
	@echo "Please type in commit comment: "; \
	read comment; \
	git commit -m"$$comment"
sync: commit
	git push -u origin $(BRANCH)
reset_hard:
	git fetch && git reset --hard origin/$(BRANCH)

PHONY += commit sync sub_pull
# build ==================================================================================
config_clang:
	cd llvm-project && cmake -G Ninja -S llvm -B build -DCMAKE_INSTALL_PREFIX=../bin -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_TARGETS_TO_BUILD='X86;Mips' -DLLVM_PARALLEL_COMPILE_JOBS=32 -DLLVM_PARALLEL_LINK_JOBS=4
config_cpu0:
	cd llvm-project && cmake -G Ninja -S llvm -B build -DCMAKE_INSTALL_PREFIX=../bin -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang' -DLLVM_TARGETS_TO_BUILD='Cpu0;X86;Mips;ARM;RISCV' -DLLVM_PARALLEL_COMPILE_JOBS=32 -DLLVM_PARALLEL_LINK_JOBS=4
build:
	cd llvm-project/build && ninja
save_change:
	python handle_change.py save
save_modify:
	python handle_change.py save_modify
restore_change:
	python handle_change.py restore
restore_modify:
	python handle_change.py restore_modify

PHONY += build config_clang config_cpu0 save_change restore_change
# test ===================================================================================
view_dag:
	clang -S -emit-llvm ./test/mytest.c -o mytest.ll -O3
	./llvm-project/build/bin/llc -march=x86 -view-dag-combine1-dags -debug mytest.ll &>log

mytest.s: ./test/mytest.c ./test/mytest.h
	./llvm-project/build/bin/clang --target=riscv64-unknown-elf -S -O3 -o $@ $<
mytest.o:mytest.s
	./llvm-project/build/bin/llvm-mc -filetype=obj -triple=riscv32 --arch=riscv32 $< -o $@

PHONY += view_dag
# clean ==================================================================================
clean:
	-rm *.bc *.ll *.s *.out log

PHONY += clean
# ========================================================================================
.PHONY: $(PHONY)