LLVM_NEW_FILES = $(shell cd llvm-project; git status --short | grep '^??' | awk '{printf "%s ", $$2}')
# git ====================================================================================
sub_pull:
	git submodule foreach --recursive 'git pull'
commit: clean
	git add -A
	@echo "Please type in commit comment: "; \
	read comment; \
	git commit -m"$$comment"
sync: commit
	git push -u origin main
test_p:
	@echo $(LLVM_NEW_FILES)

PHONY += commit sync sub_pull
# build ==================================================================================
config_clang:
	cd llvm-project && cmake -G Ninja -S llvm -B build -DCMAKE_INSTALL_PREFIX=../bin -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_PARALLEL_COMPILE_JOBS=16 -DLLVM_PARALLEL_LINK_JOBS=3
build_clang:
	cd llvm-project/build && ninja
save_change:
	python handle_change.py save
save_modify:
	python handle_change.py save_modify
restore_change:
	python handle_change.py restore
restore_modify:
	python handle_change.py restore_modify

PHONY += build_clang config_clang save_change restore_change
# test ===================================================================================
view_dag:
	clang -S -emit-llvm ./test/mytest.c -o mytest.ll -O3
	./llvm-project/build/bin/llc -view-dag-combine1-dags mytest.ll

PHONY += view_dag
# clean ==================================================================================
clean:
	-rm *.bc *.ll *.s *.out

PHONY += clean
# ========================================================================================
.PHONY: $(PHONY)