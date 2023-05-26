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
	cd llvm-project && cmake -G 'Unix Makefiles' -S llvm -B build -DCMAKE_INSTALL_PREFIX=../bin -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_TARGETS_TO_BUILD=X86
build_clang:
	cd llvm-project/build && make

PHONY += build_clang config_clang
# build ==================================================================================
clean:
	-rm *.bc

PHONY += clean
# ========================================================================================
.PHONY: $(PHONY)