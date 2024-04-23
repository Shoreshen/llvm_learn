//===- Cpu0InstrInfo.td - Target Description for Cpu0 Target -*- tablegen -*-=//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file contains the Cpu0 implementation of the TargetInstrInfo class.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Define SDNode as pattern operator
//===----------------------------------------------------------------------===//

// Return node, no input and output
def Cpu0Ret : 
SDNode<
    "Cpu0ISD::Ret",  // Node name
    SDTNone,         // Node type: Number of input/output and other info
    [SDNPHasChain, SDNPOptInGlue, SDNPVariadic] // Properties 
>;

//===----------------------------------------------------------------------===//
// Operand, used for input and output operand of instructions
//===----------------------------------------------------------------------===//

// Signed 16bit integer
def simm16 : 
Operand<i32> {
  let DecoderMethod= "DecodeSimm16";        // self defined function for decoding
}

// Address operand
def mem : 
Operand<iPTR> {
  let PrintMethod = "printMemOperand";      // self defined function for printing
  let MIOperandInfo = (ops GPROut, simm16); // Define sub operands
  let EncoderMethod = "getMemEncoding";     // self defined function for encoding
}

//===----------------------------------------------------------------------===//
// Pattern fragments, used for pattern matching
//===----------------------------------------------------------------------===//

// Signed 16bit integer
def immSExt16 : 
PatLeaf< // This is just a patfrag without sub-patten
    (imm),  // imm is defined in `llvm/include/llvm/Target/TargetSelectionDAG.td` 
            // This defines a DAG without operand
    [{ return isInt<16>(N->getSExtValue()); }] // Predicate check for instruction selection
>;

// Address
def addr : 
ComplexPattern<
    iPTR,               // Value type
    2,                  // Operand number
    "SelectAddr",       // Name of the function for instruction selection
    [frameindex],       // Root SDNode
    [SDNPWantParent]    // Properties 
>;

// Load aligned
def load_a : PatFrag<
    (ops node:$ptr),    // Define operands `ops` is the defined PatFrag
    (load node:$ptr),   // Define fitting patterns
    [{
        LoadSDNode *LD = cast<LoadSDNode>(N);
        return LD->getMemoryVT().getSizeInBits()/8 <= LD->getAlignment();
    }]                  // Check code, the reason of defining this PatFrag
>;

// Store aligned
def store_a : 
PatFrag<
    (ops node:$val, node:$ptr), 
    (store node:$val, node:$ptr), 
    [{
        StoreSDNode *SD = cast<StoreSDNode>(N);
        return SD->getMemoryVT().getSizeInBits()/8 <= SD->getAlignment();
    }]
>;


//===----------------------------------------------------------------------===//
// Instructions format
//===----------------------------------------------------------------------===//

// Generic Cpu0 Format
class Cpu0Inst<dag outs, dag ins, string asmstr, list<dag> pattern>: Instruction
{
    // Specific fields for Cpu0
    field bits<32> Inst;
    bits<8> Opcode = 0;

    // Fields in `class Instruction`
    let Namespace = "Cpu0";
    let Size = 4;
    let OutOperandList = outs;  // Output operands
    let InOperandList  = ins;   // Input operands
    let AsmString   = asmstr;   // Assembly string
    let Pattern     = pattern;
    let DecoderNamespace = "Cpu0";
}

class FA<bits<8> op, dag outs, dag ins, string asmstr,list<dag> pattern> : Cpu0Inst<outs, ins, asmstr, pattern>
{
    bits<4>  ra;
    bits<4>  rb;
    bits<4>  rc;
    bits<12> cx;

    let Inst{31-24} = op;
    let Inst{23-20} = ra;
    let Inst{19-16} = rb;
    let Inst{15-12} = rc;
    let Inst{11-0}  = cx;

    let TSFlags{3-0} = 1;   // Value in `TSFlags` field in `MCInstrDesc` class, this indicate A type instruction
}

class FL_1<bits<8> op, dag outs, dag ins, string asmstr, list<dag> pattern> : Cpu0Inst<outs, ins, asmstr, pattern>
{
    bits<4>  ra;
    bits<4>  rb;
    bits<16> imm16;

    let Inst{31-24} = op;
    let Inst{23-20} = ra;
    let Inst{19-16} = rb;
    let Inst{15-0}  = imm16;

    let TSFlags{3-0} = 2;   // Value in `TSFlags` field in `MCInstrDesc` class, this indicate L type instruction
}

class FL_2<bits<8> op, dag outs, dag ins, string asmstr, list<dag> pattern> : Cpu0Inst<outs, ins, asmstr, pattern>
{
    bits<4>     ra;
    bits<20>    addr;

    let Inst{31-24}     = op;
    let Inst{23-20}     = ra;
    let Inst{19-0}      = addr;

    let TSFlags{3-0}    = 2;   // Value in `TSFlags` field in `MCInstrDesc` class, this indicate L type instruction
}

class FJ<bits<8> op, dag outs, dag ins, string asmstr, list<dag> pattern> : Cpu0Inst<outs, ins, asmstr, pattern>
{
    bits<24> addr;

    let Inst{31-24}     = op;
    let Inst{23-0}      = addr;

    let TSFlags{3-0}    = 3;   // Value in `TSFlags` field in `MCInstrDesc` class, this indicate J type instruction
}

//===----------------------------------------------------------------------===//
// Cpu0 Instructions
//===----------------------------------------------------------------------===//

// Load and Store Instructions aligned
def LD : 
FL_2<0x01, (outs GPROut:$ra), (ins mem:$addr), "ld\t$ra, $addr", [(set GPROut:$ra, (load_a addr:$addr))]>,
Sched<[IILoad]> 
{
    let isPseudo = 0;
    let DecoderMethod = "DecodeMem";
}
def ST : 
FL_2<0x01, (outs GPROut:$ra), (ins mem:$addr), "st\t$ra, $addr", [(store_a GPROut:$ra, addr:$addr)]>,
Sched<[IIStore]> 
{
    let isPseudo = 0;
    let DecoderMethod = "DecodeMem";
}

// Arithmetic Instructions (ALU Immediate)
def ADDiu : 
FL_1<0x09, (outs GPROut:$ra), (ins CPURegs:$rb, simm16:$imm16), "addiu\t$ra, $rb, $imm16", [(set GPROut:$ra, (add CPURegs:$rb, immSExt16:$imm16))]>,
Sched<[IIAlu]> 
{
    let isReMaterializable = 1;
}

// Shift Instructions
def JR :
FL_1<0x3c, (outs), (ins GPROut:$ra), "jr\t$ra", [(brind GPROut:$ra)]>, 
Sched<[IIBranch]> 
{
    // unused operand
    let rb = 0;
    let imm16 = 0;

    // Instruction properties
    let isBranch = 1;
    let isTerminator = 1;
    let isBarrier = 1;
    let hasDelaySlot = 1;
    let isIndirectBranch = 1;
}
def RET : 
FL_1<0x3c, (outs), (ins GPROut:$ra), "ret\t$ra", [(brind GPROut:$ra)]>,
Sched<[IIBranch]> 
{
    let isReturn = 1;
    let isCodeGenOnly = 1;
    let hasCtrlDep = 1;
    let hasExtraSrcRegAllocReq = 1;
}

/// No operation
def NOP : 
FJ<0, (outs), (ins), "nop", []>,
Sched<[IIAlu]> 
{
    let addr = 0;
}

// This is used for `CompleteModel` since `COPY` is defined in `Target.td` and do not have a `Sched` class
// If not re-write, the compilation will fail
def : InstRW<[IIAlu], (instrs COPY)>
{
    let SchedModel = Cpu0genericModel;
}