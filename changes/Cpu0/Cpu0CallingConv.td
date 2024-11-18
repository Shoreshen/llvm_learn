//===-- Cpu0CallingConv.td - Calling Conventions for Cpu0 --*- tablegen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
// This describes the calling conventions for Cpu0 architecture.
//===----------------------------------------------------------------------===//


def Cpu0_CCallingConv : CallingConv<[
    // each stack slot has size of 4, alignment of 4
    CCIfByVal<CCPassByVal<4, 4>>,
    // Promote i8/i16 to i32
    CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
    // i32 are returned in registers V0, V1, A0, A1
    CCIfType<[i32], CCAssignToReg<[V0, V1, A0, A1]>>,
    // Integer values get stored in stack slots that are 4 bytes in size and 4-byte aligned
    CCIfType<[i32], CCAssignToStack<4, 4>>
]>;
//#endif

//#if CH >= CH3_4 2
def Cpu0_CRetConv : CallingConv<[
    // Promote i8/i16 to i32
    CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
    // i32 are returned in registers V0, V1, A0, A1
    CCIfType<[i32], CCAssignToReg<[V0, V1, A0, A1]>>,
    // Integer values get stored in stack slots that are 4 bytes in size and 4-byte aligned
    CCIfType<[i32], CCAssignToStack<4, 4>>
]>;
//#endi


def CSR_O32 : CalleeSavedRegs<(add LR, FP, (sequence "S%u", 1, 0))>;
