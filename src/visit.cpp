#include "visit.h"
#include "genMC.h"

#include "llvm/IR/Instructions.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/Transforms/Utils/Cloning.h"

using namespace llvm;

#define F_TYPE_RUN_ON_NPU 0

int F_count[1] = {
    0
};

const char* getStringFromValue(Value *value) {
    // 检查Value是否为GlobalVariable
    if (auto *GV = dyn_cast<GlobalVariable>(value)) {
        // 确保它有一个初始化器
        if (GV->hasInitializer()) {
            // 获取初始化器
            Constant *Init = GV->getInitializer();
            Init->print(errs());
            // 检查初始化器是否是ConstantDataArray
            if (auto CDA = dyn_cast<ConstantDataArray>(Init)) {
                if (CDA->isString()) {
                    // 提取并返回字符串数据
                    return CDA->getAsCString().data();
                }
            } if(auto *GV = dyn_cast<GlobalVariable>(Init)) {
                return getStringFromValue(GV);
            }
        }
    } else if (auto *StrInst = dyn_cast<LoadInst>(value)) {
        return getStringFromValue(StrInst->getPointerOperand());
    }
    return nullptr;  // 不是字符串或无法转换为字符串
}

void output_param_map(std::string func_name, CallInst* call) {
    std::string str = getStringFromValue(call->getOperand(0));
    std::string asm_code = genMCCode(str);
    param_map[func_name] = std::make_pair(str, asm_code);
}

Function *create_new_func_decl(Module *mod, const std::string &new_name) 
{
    // 创建一个没有参数的新函数类型
    LLVMContext &context = mod->getContext();
    FunctionType *func_type = FunctionType::get(Type::getVoidTy(context), false);

    // 创建新函数
    Function *new_func = Function::Create(func_type, Function::ExternalLinkage, new_name, mod);
    
    // 设置调用约定和其他必要的元数据，例如：
    new_func->setCallingConv(CallingConv::C);

    return new_func;
}

void replace_call(std::string func_name, Module* mod, CallInst* old_call) {
    Function *new_func = create_new_func_decl(mod, func_name);
    llvm::IRBuilder<> Builder(old_call);
    Builder.CreateCall(new_func, {});  // 空参数列表
    old_call->eraseFromParent();
}

void visit(Module* mod)
{
    std::vector<CallInst*> to_handle;
    for(Function &func : mod->getFunctionList()) {
        for (BasicBlock &BB : func) {
            for (Instruction &I : BB) {
                if (I.getOpcode() == Instruction::Call) {
                    CallInst* call = dyn_cast<CallInst>(&I);
                    to_handle.push_back(call);
                }
            }
        }
    }
    for (CallInst* call : to_handle) {
        std::string func_name = call->getCalledFunction()->getName().str();
        if (!func_name.compare(0, 10, "run_on_npu")) {
            if (call->arg_size() != 1) {
                printf("run_on_npu should have 1 operand\n");
                exit(1);
            }
            func_name = func_name + std::to_string(F_count[F_TYPE_RUN_ON_NPU]);
            output_param_map(func_name, call);
            replace_call(func_name, mod, call);
            F_count[F_TYPE_RUN_ON_NPU]++;
        };
    }
    // mod->print(errs(), nullptr);
}