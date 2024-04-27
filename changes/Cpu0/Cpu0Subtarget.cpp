//===-- Cpu0Subtarget.cpp - Cpu0 Subtarget Information --------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the Cpu0 specific subclass of TargetSubtargetInfo.
//
//===----------------------------------------------------------------------===//

#include "Cpu0Subtarget.h"

#include "Cpu0MachineFunction.h"
#include "Cpu0.h"
#include "Cpu0RegisterInfo.h"

#include "Cpu0TargetMachine.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/Function.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

#define DEBUG_TYPE "cpu0-subtarget"

#define GET_SUBTARGETINFO_TARGET_DESC
#define GET_SUBTARGETINFO_CTOR
#include "Cpu0GenSubtargetInfo.inc"

extern bool FixGlobalBaseReg;


Cpu0Subtarget::Cpu0Subtarget(const Triple &TT, StringRef CPU,
                             StringRef FS, const Cpu0TargetMachine &_TM) :
    Cpu0GenSubtargetInfo(TT, CPU, /*TuneCPU*/ CPU, FS),
    TSInfo(),
    InstrInfo(initializeSubtargetDependencies(CPU, FS, _TM)),
    FrameLowering(*this, 4),
    TLInfo(_TM, *this) { }

Cpu0Subtarget& Cpu0Subtarget::initializeSubtargetDependencies(StringRef CPU, StringRef FS,
                                               const TargetMachine &TM) {
    if (CPU.empty()) {
        CPU = "generic";
    }
    
    // Parse features string.
    ParseSubtargetFeatures(CPU, /*TuneCPU*/ CPU, FS);

    return *this;
}


