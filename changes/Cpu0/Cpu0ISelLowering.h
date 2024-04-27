//===-- Cpu0ISelLowering.h - Cpu0 DAG Lowering Interface --------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file defines the interfaces that Cpu0 uses to lower LLVM code into a
// selection DAG.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU0_CPU0ISELLOWERING_H
#define LLVM_LIB_TARGET_CPU0_CPU0ISELLOWERING_H

#include "Cpu0.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/IR/Function.h"
#include "llvm/CodeGen/TargetLowering.h"
#include <deque>

namespace llvm {
namespace Cpu0ISD {
    enum NodeType {
        // Start the numbering from where ISD NodeType finishes.
        FIRST_NUMBER = ISD::BUILTIN_OP_END,

        // Return
        Ret
    };
}

//===--------------------------------------------------------------------===//
// TargetLowering Implementation
//===--------------------------------------------------------------------===//
class Cpu0FunctionInfo;
class Cpu0Subtarget;

//@class Cpu0TargetLowering
class Cpu0TargetLowering : public TargetLowering  {
public:
    explicit Cpu0TargetLowering(const Cpu0TargetMachine &TM, const Cpu0Subtarget &STI);


    /// getTargetNodeName - This method returns the name of a target specific
    //  DAG node.
    const char *getTargetNodeName(unsigned Opcode) const override;

protected:
    // Subtarget Info
    const Cpu0Subtarget &Subtarget;

private:

    // Lower Operand specifics
    SDValue lowerGlobalAddress(SDValue Op, SelectionDAG &DAG) const;

    //- must be exist even without function all
    SDValue LowerFormalArguments(SDValue Chain,
                        CallingConv::ID CallConv, bool IsVarArg,
                        const SmallVectorImpl<ISD::InputArg> &Ins,
                        const SDLoc &dl, SelectionDAG &DAG,
                        SmallVectorImpl<SDValue> &InVals) const override;

    SDValue LowerReturn(SDValue Chain,
                        CallingConv::ID CallConv, bool IsVarArg,
                        const SmallVectorImpl<ISD::OutputArg> &Outs,
                        const SmallVectorImpl<SDValue> &OutVals,
                        const SDLoc &dl, SelectionDAG &DAG) const override;

};
}

#endif // Cpu0ISELLOWERING_H