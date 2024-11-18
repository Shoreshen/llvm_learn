//===-- Cpu0FrameLowering.h - Define frame lowering for Cpu0 ----*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
//
//
//===----------------------------------------------------------------------===//
#ifndef LLVM_LIB_TARGET_CPU0_CPU0FRAMELOWERING_H
#define LLVM_LIB_TARGET_CPU0_CPU0FRAMELOWERING_H

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {
  
class Cpu0Subtarget;

class Cpu0FrameLowering : public TargetFrameLowering {
protected:
    const Cpu0Subtarget &STI;

public:
    explicit Cpu0FrameLowering(const Cpu0Subtarget &sti, unsigned Alignment)
        : TargetFrameLowering(StackGrowsDown, Align(Alignment), 0, Align(Alignment)),
        STI(sti) {
    }

    void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
    void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override;

    bool hasFP(const MachineFunction &MF) const override;

};

} // End llvm namespace

#endif