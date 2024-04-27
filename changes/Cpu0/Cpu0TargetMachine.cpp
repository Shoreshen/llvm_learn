//===-- Cpu0TargetMachine.cpp - Define TargetMachine for Cpu0 -------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Implements the info about Cpu0 target spec.
//
//===----------------------------------------------------------------------===//

#include "Cpu0TargetMachine.h"
#include "Cpu0.h"

#include "Cpu0Subtarget.h"
#include "Cpu0TargetObjectFile.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/Function.h"
#include "llvm/Support/CodeGen.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Target/TargetOptions.h"

using namespace llvm;

#define DEBUG_TYPE "cpu0"

extern "C" void LLVMInitializeCpu0Target() {
  // Register the target.
  RegisterTargetMachine<Cpu0TargetMachine> X(TheCpu0Target);
}

static std::string computeDataLayout(const Triple &TT, StringRef CPU, const TargetOptions &Options) {
    std::string Ret = "";

    // little endian, big endian is "E"
    Ret += "e";

    // Name mangling model relating to re-naming conflict symbols, just use "-m:e" MM_ELF 
    Ret += "-m:e";

    // Pointers are 32 bit on some ABIs.
    Ret += "-p:32:32";

    // 8 and 16 bit integers only need to have natural alignment, but try to
    // align them to 32 bits. 64 bit integers have natural alignment.
    Ret += "-i8:8:32-i16:16:32-i64:64";

    // 32 bit registers are always available and the stack is at least 64 bit
    // aligned.
    Ret += "-n32-S64";

  return Ret;
}

static Reloc::Model getEffectiveRelocModel(bool JIT, std::optional<Reloc::Model> RM) {
    if (!RM || JIT)
        return Reloc::Static;
    return *RM;
}

// DataLayout --> Big-endian, 32-bit pointer/ABI/alignment
// The stack is always 8 byte aligned
// On function prologue, the stack is created by decrementing
// its pointer. Once decremented, all references are done with positive
// offset from the stack/frame pointer, using StackGrowsUp enables
// an easier handling.
// Using CodeModel::Large enables different CALL behavior.
Cpu0TargetMachine::Cpu0TargetMachine(
    const Target &T, const Triple &TT,
    StringRef CPU, StringRef FS,
    const TargetOptions &Options,
    std::optional<Reloc::Model> RM,
    std::optional<CodeModel::Model> CM,
    CodeGenOptLevel OL, bool JIT
) : LLVMTargetMachine(
    T, 
    computeDataLayout(TT, CPU, Options), 
    TT,
    CPU, 
    FS, 
    Options, 
    getEffectiveRelocModel(JIT, RM),
    getEffectiveCodeModel(CM, CodeModel::Small), 
    OL
),
TLOF(std::make_unique<Cpu0TargetObjectFile>()) {
  // initAsmInfo will display features by llc -march=cpu0 -mcpu=help on 3.7 but
  // not on 3.6
  initAsmInfo();
}

const Cpu0Subtarget* Cpu0TargetMachine::getSubtargetImpl(const Function &F) const {
    std::string CPU = TargetCPU;
    std::string FS = TargetFS;

    auto &I = SubtargetMap[CPU + FS];
    if (!I) {
        // This needs to be done before we create a new subtarget since any
        // creation will depend on the TM and the code generation flags on the
        // function that reside in TargetOptions.
        resetTargetOptions(F);
        I = std::make_unique<Cpu0Subtarget>(TargetTriple, CPU, FS, *this);
    }
    return I.get();
}

namespace {
//@Cpu0PassConfig {
/// Cpu0 Code Generator Pass Configuration Options.
class Cpu0PassConfig : public TargetPassConfig {
public:
    Cpu0PassConfig(Cpu0TargetMachine &TM, PassManagerBase &PM)
        : TargetPassConfig(TM, PM) {}

    Cpu0TargetMachine &getCpu0TargetMachine() const {
        return getTM<Cpu0TargetMachine>();
    }
};
} // namespace

TargetPassConfig *Cpu0TargetMachine::createPassConfig(PassManagerBase &PM) {
    return new Cpu0PassConfig(*this, PM);
}
