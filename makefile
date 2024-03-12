# git ====================================================================================
sub_pull:
	git submodule foreach --recursive 'git pull'
commit: clean
	git add -A
	@echo "Please type in commit comment: "; \
	read comment; \
	git commit -m"$$comment"
sync: sub_pull commit
	git push -u origin main

PHONY += commit sync sub_pull
# build ==================================================================================
config_clang:
	cd llvm-project && cmake -G Ninja -S llvm -B build -DCMAKE_INSTALL_PREFIX=../bin -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_PARALLEL_COMPILE_JOBS=16 -DLLVM_PARALLEL_LINK_JOBS=3
build_clang:
	cd llvm-project/build && ninja

PHONY += build_clang config_clang
# test ===================================================================================
view_dag:
	clang -S -emit-llvm ./test/mytest.c -o mytest.ll -O3
	./llvm-project/build/bin/llc -view-dag-combine1-dags mytest.ll
# clean ==================================================================================
clean:
	-rm *.bc *.ll *.s *.out

PHONY += clean
# ========================================================================================
.PHONY: $(PHONY)