# $@  表示目标文件
# $^  表示所有的依赖文件
# $<  表示第一个依赖文件
# $?  表示比目标还要新的依赖文件列表
LLVM_NEW_FILES = $(shell cd llvm-project; git status --short | grep '^??' | awk '{printf "%s ", $$2}')
BRANCH = $(shell git symbolic-ref --short HEAD)
SRC_C = $(filter-out ./src/main.cpp, $(wildcard ./src/*.cpp))
OBJ_C = $(patsubst %.cpp,%.o,$(SRC_C))
SRC_H = $(wildcard ./src/*.h)
CFLAGS = -m64 -g -lLLVM -static-libstdc++
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
	cd llvm-project && cmake -G Ninja -S llvm -B build -DCMAKE_INSTALL_PREFIX=../bin -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" -DLLVM_TARGETS_TO_BUILD='Cpu0;X86;Mips;ARM;RISCV' -DLLVM_PARALLEL_COMPILE_JOBS=32 -DLLVM_PARALLEL_LINK_JOBS=4
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

mytest.ll: ./test/mytest.c ./test/mytest.h
	./llvm-project/build/bin/clang --target=riscv64-unknown-linux-gnu -S -emit-llvm -fPIC -O3 -o $@ $<

mytest.o:mytest.ll
	./llvm-project/build/bin/clang --target=riscv64-unknown-linux-gnu -fPIC -c -o $@ $<

mytest.so:mytest.o
	riscv64-unknown-linux-gnu-gcc -shared -o mytest.so mytest.o

dumpmytest:mytest.so
	riscv64-unknown-linux-gnu-objdump -d mytest.so

mytest_comp.bc: ./test/mytest.c
	./llvm-project/build/bin/clang --target=riscv64 -emit-llvm -O3 -c $< -o $@

mytest_comp.ll: mytest_comp.bc comp.out
	./comp.out -ll $@ $<

mytest_comp.s: mytest_comp.ll
	./llvm-project/build/bin/llc -march=riscv64 -o $@ $<

mytest_comp.o:mytest_comp.s
	./llvm-project/build/bin/llvm-mc -filetype=obj -triple=riscv64 --arch=riscv64 $< -o $@

PHONY += view_dag dumpmytest
# Compiler ===============================================================================
$(OBJ_C):%.o:%.cpp %.h ./src/util.h
	g++ $(CFLAGS) -c $< -o $@
./src/main.o: ./src/main.cpp $(SRC_H) ./src/util.h
	g++ $(CFLAGS) -c ./src/main.cpp -o $@
comp.out:./src/main.o $(OBJ_C)
	g++ $(OBJ_C) $< $(CFLAGS) -o $@

# clean ==================================================================================
clean:
	-rm *.bc *.ll *.s *.out log *.o src/*.o param_map.txt *.so

PHONY += clean
# ========================================================================================
.PHONY: $(PHONY)