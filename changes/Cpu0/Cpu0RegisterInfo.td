//===-- Cpu0RegisterInfo.td - Cpu0 Register defs -----------*- tablegen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//  Declarations that describe the CPU0 register file
//===----------------------------------------------------------------------===//

// We have banks of 16 registers each.
class Cpu0Reg<bits<16> Enc, string n> : Register<n> {
  // For tablegen(... -gen-emitter)  in CMakeLists.txt
  let HWEncoding = Enc;
  let Namespace = "Cpu0";
}

def ZERO : Cpu0Reg<0,  "zero">, DwarfRegNum<[0]>;   // Constant register, value is 0
def AT   : Cpu0Reg<1,  "1">,    DwarfRegNum<[1]>;   // General-purpose registers
def V0   : Cpu0Reg<2,  "2">,    DwarfRegNum<[2]>;   // General-purpose registers
def V1   : Cpu0Reg<3,  "3">,    DwarfRegNum<[3]>;   // General-purpose registers
def A0   : Cpu0Reg<4,  "4">,    DwarfRegNum<[4]>;   // General-purpose registers
def A1   : Cpu0Reg<5,  "5">,    DwarfRegNum<[5]>;   // General-purpose registers
def T9   : Cpu0Reg<6,  "t9">,   DwarfRegNum<[6]>;   // General-purpose registers
def T0   : Cpu0Reg<7,  "7">,    DwarfRegNum<[7]>;   // General-purpose registers
def T1   : Cpu0Reg<8,  "8">,    DwarfRegNum<[8]>;   // General-purpose registers
def S0   : Cpu0Reg<9,  "9">,    DwarfRegNum<[9]>;   // General-purpose registers
def S1   : Cpu0Reg<10, "10">,   DwarfRegNum<[10]>;  // General-purpose registers
def GP   : Cpu0Reg<11, "gp">,   DwarfRegNum<[11]>;  // Global pointer
def FP   : Cpu0Reg<12, "fp">,   DwarfRegNum<[12]>;  // Frame pointer
def SP   : Cpu0Reg<13, "sp">,   DwarfRegNum<[13]>;  // Stack pointer
def LR   : Cpu0Reg<14, "lr">,   DwarfRegNum<[14]>;  // Link register
def SW   : Cpu0Reg<15, "sw">,   DwarfRegNum<[15]>;  // Status Word

def PC   : Cpu0Reg<0, "pc">,  DwarfRegNum<[20]>;    // Program Counter
def EPC  : Cpu0Reg<1, "epc">, DwarfRegNum<[21]>;    // Error Program Counter


//===----------------------------------------------------------------------===//
//@Register Classes
//===----------------------------------------------------------------------===//

def CPURegs : RegisterClass<
    "Cpu0", [i32], 32, 
    (add ZERO, AT, V0, V1, A0, A1, T9, T0, T1, S0, S1, GP, FP, SP, LR, SW)
>;

//@Co-processor 0 Registers class
def C0Regs : RegisterClass<"Cpu0", [i32], 32, (add PC, EPC)>;
// General purpose registers
def GPROut : RegisterClass<"Cpu0", [i32], 32, (add CPURegs, SW)>;

