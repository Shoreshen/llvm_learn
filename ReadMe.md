# 简介

LLVM的基本流程如下

<img src="pic/5a43a2c1bc664e26a57c4cb4e8b25109.png">

面对不同前后端

<img src="pic/8e397bb56bed55c611de43a02cf1647f.png">

文件流

<img src="pic/fileflow.drawio.png">

# Backend CodeGen

## Tablegen

### multiclass

Used to define multiple record once, see the following example:

```tablegen
def ops;
def GPR;
def Imm;
class inst <int opc, string asmstr, dag operandlist>;

multiclass ri_inst <int opc, string asmstr> {
  def _rr : inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
  def _ri : inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
}

// Define records for each instruction in the RR and RI formats.
defm ADD : ri_inst<0b111, "add">;
```

This will define 2 records, which is equivalent to the following:

```tablegen
def ops;
def GPR;
def Imm;
class inst <int opc, string asmstr, dag operandlist>;

def ADD_rr : inst<0b111, !strconcat("add", " $dst, $src1, $src2"),
                (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
def ADD_ri : inst<0b111, !strconcat("add", " $dst, $src1, $src2"),
                (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
```

#### Inherent `NAME` arg

`NAME` is a inherent argument for `multiclass`, If a record defined inside `multiclass` and did not use the argument `NAME`, then the following is equivalent:

```tablegen
defm Foo        : SomeMultiClass<...>;
defm NAME # Foo : SomeMultiClass<...>;
```

Here is an example

```tablegen
def ops;
def GPR;
def Imm;
class inst <int opc, string asmstr, dag operandlist>;

multiclass ri_inst <int opc, string asmstr> {
  def SUB_rr : inst<opc, !strconcat(NAME, " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
  def _ri : inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
}

// Define records for each instruction in the RR and RI formats.
defm ADD : ri_inst<0b111, "add">;
```

This is equivalent to the following:

```tablegen
def ops;
def GPR;
def Imm;
class inst <int opc, string asmstr, dag operandlist>;

def SUB_rr : inst<0b111, !strconcat("ADD", " $dst, $src1, $src2"),
                (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
def ADD_ri : inst<0b111, !strconcat("add", " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
```

#### Subclass

Sub class of `multiclass` has to be a `multiclass`, it will create all records defined in the `multiclass` and its base class with the same `NAME` argument. See example:

```tablegen
def ops;
def GPR;
def Imm;
class inst <int opc, string asmstr, dag operandlist>;

multiclass rr_inst <int opc, string asmstr> {
  def _rr : inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
}

multiclass ri_inst <int opc, string asmstr> : rr_inst<opc, asmstr> {
  def _ri : inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                   (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
}

defm ADD : ri_inst<0b111, "add">;
```

This is equivalent to the following:

```tablegen
def ops;
def GPR;
def Imm;
class inst <int opc, string asmstr, dag operandlist>;

def ADD_rr : inst<0b111, !strconcat("add", " $dst, $src1, $src2"),
                (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
def ADD_ri : inst<0b111, !strconcat("add", " $dst, $src1, $src2"),
                (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
```

## Basic procedure

### Example-AMDGPU

Using [testAMD.c](./test/testAMD.c) as source, compiling device only llvm ir `testAMD.ll` using the following command:

```shell
./llvm-project/build/bin/clang -x hip --cuda-gpu-arch=gfx1100 --cuda-device-only -S -I/opt/rocm/include -emit-llvm -o testAMD.ll ./test/testAMD.c -O3
```

Focus on the process of assembly generation from `testAMD.ll` with the following command:

```shell
./llvm-project/build/bin/llc -enable-misched -fast-isel=0 testAMD.ll -o testAMD.il
```

### Start up

Start with [`mian`](llvm-project/llvm/tools/llc/llc.cpp#L319) function, calling [`compileModule`](llvm-project/llvm/tools/llc/llc.cpp#L446) after few check works.

### Main backend process

Within the [`compileModule`](llvm-project/llvm/tools/llc/llc.cpp#L446) function, the main backend process is as follow:

1. Set up `std::unique_ptr<TargetMachine> Target` 
   1. `Target` is the instantiation of target specific `TargetMachine` class, in this case its the [`GCNTargetMachine`](llvm-project/llvm/lib/Target/AMDGPU/AMDGPUTargetMachine.cpp#L867) instance
   2. In this case, it is set by parsing IR file with lambda function call names `SetDataLayout`
2. Create pass manager, in this case we use legacy pass manager
3. Add code generation passes by calling [`addPassesToEmitFile`](llvm-project/llvm/lib/CodeGen/LLVMTargetMachine.cpp#L209) function
4. Run different passes to finish [Instruction selection](#instruction-schedule), [Instruction scheduling](#instruction-schedule) and [Register allocation](#register-allocation)

### [`TargetPassConfig`](llvm-project/llvm/include/llvm/CodeGen/TargetPassConfig.h#L85)

Target need to construct subclass of `TargetPassConfig` to define the passes that will be added.

A series of functions can be overridden to add target specific passes, some of the important functions are:

1. If using selection DAG instruction selector, then `addInstSelector` function should be overridden
2. If using global instruction selector, then `addIRTranslator`, `addLegalizeMachineIR`, `addRegBankSelect` and `addGlobalInstructionSelect` function should be overridden

## Instruction Schedule

### Example

C file:

```c
void test(int a, int *x, int *y)
{
    int b = a * x[0] + y[0];
    int c = b + x[1];
    int d = c * y[1];
    y[2] = b + c + d;
}
```

DAG print out:

```llvm
bb.0 (%ir-block.3): liveins: $edi, $rsi, $rdx
    %2:gr64 = COPY $rdx
    %1:gr64 = COPY $rsi
    %4:gr32 = COPY $edi
    %4:gr32 = nsw IMUL32rm %4:gr32(tied-def 0), %1:gr64, 1, $noreg, 0, $noreg, implicit-def dead $eflags :: (load (s32) from %ir.1, !tbaa !5)
    %4:gr32 = nsw ADD32rm %4:gr32(tied-def 0), %2:gr64, 1, $noreg, 0, $noreg, implicit-def dead $eflags :: (load (s32) from %ir.2, !tbaa !5)
    %7:gr32 = MOV32rm %1:gr64, 1, $noreg, 4, $noreg :: (load (s32) from %ir.8, !tbaa !5)
    %7:gr32 = ADD32rr %7:gr32(tied-def 0), %4:gr32, implicit-def dead $eflags
    %6:gr32 = MOV32rm %2:gr64, 1, $noreg, 4, $noreg :: (load (s32) from %ir.11, !tbaa !5)
    %6:gr32 = IMUL32rr %6:gr32(tied-def 0), %7:gr32, implicit-def dead $eflags
    %7:gr32 = nsw ADD32rr %7:gr32(tied-def 0), %4:gr32, implicit-def dead $eflags
    %7:gr32 = nsw ADD32rr %7:gr32(tied-def 0), %6:gr32, implicit-def dead $eflags
    MOV32mr %2:gr64, 1, $noreg, 8, $noreg, %7:gr32 :: (store (s32) into %ir.16, !tbaa !5)
    RET 0
```

We focus on the `IMUL32rm` instruction.

### Definition structure

#### Schedule write type

Just a name for different schedule write type, the base class is [`SchedWrite`](llvm-project/llvm/include/llvm/Target/TargetSchedule.td#L225).

From the [example](#example), the `IMUL32rm` instruction's related schedule class are defined as follow:

```tablegen
multiclass X86SchedWritePair<SchedRead ReadAfter = ReadAfterLd> {
    // Register-Memory operation.
    def Ld : SchedWrite;
    // Register-Register operation.
    def NAME : X86FoldableSchedWrite {
        let Folded = !cast<SchedWrite>(NAME#"Ld");
        let ReadAfterFold = ReadAfter;
    }
}

defm WriteIMul32Reg : X86SchedWritePair; // Integer 32-bit multiplication by register.
/*
def Ld : SchedWrite;
def WriteIMul32Reg : X86FoldableSchedWrite {
    // Here `WriteIMul32RegLd` must be defined somewhere else
    let Folded = !cast<SchedWrite>(WriteIMul32RegLd);
    let ReadAfterFold = ReadAfterLd;
}
*/
```

`IMUL32rm`'s schedule wrte type is `WriteIMul32Reg`, whose base class is `SchedWrite`.

#### Schedule read type

Same as [schedule write type](#schedule-write-type), it just name a type for schedule read type. The base class is [`SchedRead`](llvm-project/llvm/include/llvm/Target/TargetSchedule.td#L229).

From the [example](#example), the `IMUL32rm` instruction's related schedule class are defined as follow:

```tablegen
def ReadAfterLd : SchedRead;
```

`IMUL32rm`'s schedule read type is `ReadAfterLd`.

#### Attach Schedule Class to Instruction

By adding another base class of `Sched<list<SchedReadWrite> schedrw>` to instruction's definition, it attach a list of schedule class to the instruction.

The definition is as follow:

```tablegen
class Sched<list<SchedReadWrite> schedrw> {
    list<SchedReadWrite> SchedRW = schedrw;
}
```

1. For each `def` of instruction, it must list one `SchedWrite` type in order, at least provide the latency of each result.
2. For each `use` of instruction, it can be optionally list  `SchedRead` type in order. Used to define [Pipeline bypass](#pipeline-bypass) (instruction need the operand some cycles after dispatched)

Back to the [example](#example), the `IMUL32rm` instruction's attach schedule class are defined as follow:

```tablegen
class BinOpRM<bits<8> o, string m, string args, X86TypeInfo t, dag out, list<dag> p>
  : ITy<o, MRMSrcMem, t, out, (ins t.RegClass:$src1, t.MemOperand:$src2), m,
        args, p>,
    Sched<[WriteALU.Folded, WriteALU.ReadAfterFold]> 
{
    let mayLoad = 1;
}
class BinOpRM_RF<bits<8> o, string m, X86TypeInfo t, SDPatternOperator node, bit ndd = 0>
  : BinOpRM<o, m, !if(!eq(ndd, 0), binop_args, binop_ndd_args), t, (outs t.RegClass:$dst),
            [(set t.RegClass:$dst, EFLAGS, (node t.RegClass:$src1,
             (t.LoadNode addr:$src2)))]>, DefEFLAGS, NDD<ndd>;

class IMulOpRM_RF<X86TypeInfo t, X86FoldableSchedWrite sched, bit ndd = 0>
: BinOpRM_RF<0xAF, "imul", t, X86smul_flag, ndd> {
    let Form = MRMSrcMem;
    // `SchedRW` is member of `class Sched`, this mean to rewrite `Sched`
    // According to the content, `sched.Folded = WriteIMul32RegLd` and `sched.ReadAfterFold = ReadAfterLd`
    let SchedRW = [sched.Folded, sched.ReadAfterFold]; //SchedRW = [WriteIMul32RegLd, ReadAfterLd]
}

def IMUL32rm : IMulOpRM_RF<Xi32, WriteIMul32Reg>, TB, OpSize32;
```

`SchedRW` is the member of `Sched<list<SchedReadWrite> schedrw>`, by re-defining it the `IMUL32rm` instruction attach the schedule classes.

From the [first](#schedule-write-type) and [second](#schedule-read-type) we can analyze that:

1. Schedule classes `SchedRW = [WriteIMul32RegLd, ReadAfterLd]`
2. The inputs of the instruction are `GR32:$src1, i32mem:$src2` and the output is `GR32:$dst`

#### Processor resource

This section rules out the processor's resources that used by instructions, in order to include the usage of each resource in to the schedule model.

The major class used in this section are [`ProcResource`](llvm-project/llvm/include/llvm/Target/TargetSchedule.td#L197) and some of the major parameters are:

| Param      | Illustration                                                                               |
| ---------- | ------------------------------------------------------------------------------------------ |
| NumUnits   | Number of this resource                                                                    |
| BufferSize | Detailed [below](#buffersize)                                                              |
| Super      | Optional, indicting that use of this resources implies using of one of the super resources |
| SchedModel | Must, ties to [Machine Model](#machine-model)                                              |

Back to the [example](#example), the `IMUL32rm` instruction needs the following resources:

```tablegen
def SBPort1 : ProcResource<1>;
def SBPort23 : ProcResource<2>;
```

##### BufferSize

1. `BufferSize = -1`:
    This means the resource shares reservation station with CPU (out-of-order processor's instruction buffer).
    A more simple description is that this resource can accept instructions while the CPU's reservation station is not full.

2. `BufferSize = 0`:
    Assume at time `t` one of the instruction uses this resource stated execution. 
    Then it means from the moment `t + AcquireAtCycles` to `t + ReleaseAtCycles` (defined in [`WriteRes`](#write-resource))
    If there is subsequent instructions that uses this resource, the pipeline will stall

3. `BufferSize = 1`:
    This means the resource is well pipelined with the CPU, thus subsequent instruction uses the same resource will be accepted. 
    Stall will happen if the instruction's operand is not ready.

4. `BufferSize > 1`:
    This means the resource has it's own reservation station.

#### Write resource

This defines the resources and latency of a [`SchedWrite`](#schedule-write-type) type.

The major class used in this section are [`WriteRes`](llvm-project/llvm/include/llvm/Target/TargetSchedule.td#L310) and some of the major parameters are:

| Param           | Illustration                                                                                                                                                                                                                                                                                        |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ReleaseAtCycles | Valid when `BufferSize = 1`, detailed information illustrated in [BufferSize](#buffersize)<br>Note: Default value is list of `0`.                                                                                                                                                                   |
| AcquireAtCycles | Valid when `BufferSize = 1`, detailed information illustrated in [BufferSize](#buffersize)<br>Note: Default value is list of `0`.                                                                                                                                                                   |
| Latency         | If instruction is executed at time `t`, the result of it will be ready and can be used by other instructions after `t + Latency`                                                                                                                                                                    |
| NumMicroOps     | Used to model instruction buffer (reservation station): <br> 1. if `BufferSize > 1`, then the resource will stall if total number of micro-ops greater than `BufferSize`<br>2. Otherwise, the processor will stall if micro-ops greater than `MicroOpBufferSize` in [Machine Model](#machine-model) |

Back to the [example](#example), the `IMUL32rm` instruction needs the following write resources:

```tablegen
multiclass SBWriteResPair<X86FoldableSchedWrite SchedRW,
                        list<ProcResourceKind> ExePorts,
                        int Lat, list<int> Res = [1], int UOps = 1,
                        int LoadLat = 5, int LoadUOps = 1> {
    // Register variant is using a single cycle on ExePort.
    def : WriteRes<SchedRW, ExePorts> {
        let Latency = Lat;
        let ReleaseAtCycles = Res;
        let NumMicroOps = UOps;
    }

    // Memory variant also uses a cycle on port 2/3 and adds LoadLat cycles to
    // the latency (default = 5).
    def : WriteRes<SchedRW.Folded, !listconcat([SBPort23], ExePorts)> {
        let Latency = !add(Lat, LoadLat);
        let ReleaseAtCycles = !listconcat([1], Res);
        let NumMicroOps = !add(UOps, LoadUOps);
    }
}

defm : SBWriteResPair<WriteIMul32Reg, [SBPort1],   3>;
/*
def : WriteRes<WriteIMul32Reg, [SBPort1]> {
    let Latency = 3;
    let ReleaseAtCycles = [1];
    let NumMicroOps = 1;
}

// Memory variant also uses a cycle on port 2/3 and adds LoadLat cycles to
// the latency (default = 5).
def : WriteRes<WriteIMul32RegLd, [SBPort23, SBPort1]> {
    let Latency = 8;
    let ReleaseAtCycles = [1, 1];
    let NumMicroOps = 2;
}
*/
```

From the definition above, we can analyze that:

1. From [previous section](#attach-schedule-class-to-instruction), `IMUL32rm` only has one output and its schedule write type is `WriteIMul32RegLd`. 
   Thus, that output will be available after 8 cycles after the instruction is dispatched
2. This instruction will take 2 slot in the reservation station.
3. It is beleived that `ReleaseAtCycles` does not provide information since from [Processor resource](#processor-resource) we can see the default value for `BufferSize` is `-1`.

#### Pipeline bypass

This section defines the latency of the instruction's operand, which means the operand of an instruction will be needed after `n` cycles after the instruction is dispatched.

The major class used in this section are [`ReadAdvance`](llvm-project/llvm/include/llvm/Target/TargetSchedule.td#L343)

Key parameter is `Cycles`, which means the operand of an instruction will be needed after `n` cycles after the instruction is dispatched.

Back to the [example](#example), the `IMUL32rm` instruction needs the following read resources:

```tablegen
def : ReadAdvance<ReadAfterLd, 5>;
```

From [previous section](#attach-schedule-class-to-instruction), `IMUL32rm` has 2 operands, only the first one has a schedule read type of `ReadAfterLd`

From this we can know that the first operand of `IMUL32rm` will be needed after 5 cycles after the instruction is dispatched.

#### Machine Model

Used to define macro properties of the chip, the instance of [`class SchedMachineModel`](llvm-project/llvm/include/llvm/Target/TargetSchedule.td#L76), some of the key parameters are:

1. `MicroOpBufferSize` size of reservation station, if `MicroOpBufferSize = 0` then in-order processor
2. `IssueWidth` number of micro-ops can be issued per-cycle.
3. `LoadLatency` Cycles for loads to access the cache (L1 no miss)
4. `MispredictPenalty` Branch mis-predict penalty (in cycles)
5. `CompleteModel` if is `true`, then all instruction has a SchedRW or Instruction itinerary, will report error if not

### Source code and related structures

Entry point of debug is [here](llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp#L433) 

## Instruction Selection

### Instruction Define

#### DAG

A DAG of tablegen has the form of `(operator operand_1, operand_2, ...)` for each sub DAG, it can have a name by `(operator operand_1:$name_1, operand_2:$name_2, ...)`

1. `operator` refers to [DAG operator](#dag-operator)
2. `operand_i` can be [DAG operand](#dag-operand) or a sub-DAG, only [DAG operand](#dag-operand) have a value with it.
3. `name_i` refers to the name [DAG operand](#dag-operand), can be used to [value variables](#instruction)
4. User can also define "macro" like mappings to simplify the pattern match recognitions

##### DAG operand

Any instance with the sub-class or class of [`class DAGOperand`](llvm-project/llvm/include/llvm/Target/Target.td#L245), wildly used sub-classes are [RegisterClass](#registerclass) and [Operand](#operand).

###### RegisterClass

Use to define a class of register that is available for register allocation.

While register allocation happens, the allocator will pick a register from the class.

The related variables defined then will be valued

Defined in [Target.td](llvm-project/llvm/include/llvm/Target/Target.td#255) and its key parameters:

1. `regTypes`: register value type (e.g int, float, vector type)
2. `alignment`: alignment required of the registers when they are stored or loaded to memory
3. `regList`: form of `(add dag_1, dag_2, ...)` in this case the `dag_i` must be sub-class or class of [`class Register`](llvm-project/llvm/include/llvm/Target/Target.td#L163). This list out all the registers in this register class

###### Operand

Used to define address, values that can be determined while compiling other than register

For example, there may be addresses in stack result from register spill, which can only be found while compilation and can be different for different programs

The base class is [`class Operand`](llvm-project/llvm/include/llvm/Target/Target.td#997) and key parameters are:

1. `Type`: the type of this operand
2. `PrintMethod`: name of the function to call when printing this operand
3. `MIOperandInfo`: Sub-DAG definition, with form of `(ops dag_1, dag_2, ...)`, if example defined as `def MEMrr : Operand<i32> {...;let MIOperandInfo = (ops IntRegs, IntRegs);}` then:
   1. `MEMrr:$addr` can be used as operand of a DAG, while `addr` can be used to value variables illustrated [below](#instruction)
   2. `(MEMri $rs1, $simm13):$addr` can be used as operand of a DAG, in this case `rs1`, `simm13` and `addr` can all be used to value variables illustrated [below](#instruction)
4. `EncoderMethod`: self defined function for encoding

##### DAG operator

A DAG operator can be:

1. Any sub-class or class of [`class SDPatternOperator`](llvm-project/llvm/include/llvm/CodeGen/SDNodeProperties.td#L12), Widely used sub-classes are [SDNode](#sdnode)
2. Some [special operators](#special-operators)

###### SDNode

The base class is [`class SDNode`](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L332) and key parameters are:

1. `Opcode`: opcode of the node
2. `typeprof`: instance of [`class SDTypeProfile`](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L97), implement number of output/input operands and constraints
3. `Properties`: `list` of `class SDNodeProperty` (available properties are listed in [SDNodeProperties.td](llvm-project/llvm/include/llvm/CodeGen/SDNodeProperties.td))

###### Special operators 

Including `ins`, `outs`, `set`, `ops` and etc which has no base class. These operators are used for special cases including:

1. `ins`: special operator for instruction's `InOperandList`, which is the `uses` of the instruction
2. `outs`: special operator for instruction's `OutOperandList`, which is the `defs` of the instruction
3. `ops`: used in `MIOperandInfo` of [`class Operand`](#operand) to list out the operands of the operand
4. `set`: used in `pattern` element of instruction to define the pattern in instruction selection

##### Pattern mapping

Mapping a self defined operator and its operands to a set of DAGs.

###### ComplexPattern

Any sub-class or class of [`class ComplexPattern`](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L1999), key parameters are:

1. `Ty`: value type of the root node
2. `numops`: number of operand returned by `SelectFunc` (passed in as pointer parameter) after the first parameter.
3. `roots`: list of possible root nodes of the sub-DAGs to match, the first parameter of `SelectFunc` is always the found possible root node
4. `SelectFunc`: name of the self-defined selection function

This is used to define and self-written instruction selection function to match the DAG.

###### PatFrags

Defined [here](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L927) key parameters are:

1. `ops`: an accepting DAG format, with form of `(ops, node:$name_1, node:name_2, ...)`
2. `frags`: list of DAGs that can be matched
3. `pred`: check code for validation

The way that `PatFrags` is used is as follow:

1. Put the defined `PatFrags` in the accepting format, which is replace `ops` by the `PatFrags` name, and `node:$name_i` by [DAG operand](#dag-operand)
2. Then it will replace of the `node:$name_i` node in all of DAGs in `frags` by the [DAG operand](#dag-operand)
3. The replaced `frags` then will be use to match patterns 

One of the example listed in [here](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L1490) as follow:

```tablegen
def node;
def any_fadd       : PatFrags<(ops node:$lhs, node:$rhs),
                              [(strict_fadd node:$lhs, node:$rhs),
                               (fadd node:$lhs, node:$rhs)]>;
```

And the following instruction definition in [X86InstrFPStack.td](llvm-project/llvm/lib/Target/X86/X86InstrFPStack.td#L188)

```tablegen
let hasNoSchedulingInfo = 1 in {
    defm ADD : FPBinary_rr<any_fadd>;
    ...
}
```

By tracing back the definition, we have:

```tablegen
class X86Inst<bits<8> opcod, Format f, ImmType i, dag outs, dag ins,
              string AsmStr, Domain d = GenericDomain>
    : Instruction {
    ...
}

class PseudoI<dag oops, dag iops, list<dag> pattern>
    : X86Inst<0, Pseudo, NoImm, oops, iops, ""> {
    let Pattern = pattern;
}

class FpI_<dag outs, dag ins, FPFormat fp, list<dag> pattern>
    : PseudoI<outs, ins, pattern> {
    ...
}

class FpIf32<dag outs, dag ins, FPFormat fp, list<dag> pattern> :
             FpI_<outs, ins, fp, pattern>, Requires<[FPStackf32]>;

multiclass FPBinary_rr<SDPatternOperator OpNode> {
    // Register op register -> register
    // These are separated out because they have no reversed form.
    def _Fp32 : FpIf32<(outs RFP32:$dst), (ins RFP32:$src1, RFP32:$src2), TwoArgFP,
        [(set RFP32:$dst, (OpNode RFP32:$src1, RFP32:$src2))]>;
    ...
}

let hasNoSchedulingInfo = 1 in {
    defm ADD : FPBinary_rr<any_fadd>;
    ...
}
```

It is not hard to find the `Pattern` in the final instruction definition is `[(set RFP32:$dst, (any_fadd RFP32:$src1, RFP32:$src2))]`, then

1. `(any_fadd RFP32:$src1, RFP32:$src2)` is an accepting format, which corresponding `RFP32:$src1` to `node:$lhs` and `RFP32:$src2` to `node:$rhs` respectively
2. The `frags` of `any_fadd` will replace `node:$lhs` and `node:$rhs` by `RFP32:$src1` and `RFP32:$src2`, results as `[(strict_fadd RFP32:$lhs, RFP32:$rhs), (fadd RFP32:$lhs, RFP32:$rhs)]`
3. The matching pattern of the instruction will internally splite into two patterns, which are  `(set RFP32:$dst, (strict_fadd RFP32:$src1, RFP32:$src2))` and `(set RFP32:$dst, (fadd RFP32:$src1, RFP32:$src2))`.
   This means both of the above patterns will be matched by the instruction

###### PatFrag

defined [here](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L1022), just a convenient definition for [PatFrags](#patfrags) with 1 operand.

###### PatLeaf

defined [here](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L1034), just a convenient definition for [PatFrags](#patfrags) with 0 operand.

###### Pat

defined [here](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#L2067), this is used to add extra pattern to match instructions.

The key parameters are:

1. `pattern`: DAG to match
2. `result`: matched form of instruction

For example we defined an simple `ADD` instruction (Note the small add is ISD DAG node defined in [TargetSelectionDAG.td](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td#402)):

```tablegen
def Frags : PatFrags<
    (ops node:$a, node:$b), 
    [
        (add node:$a, node$:b), 
        (mul node:$a, (div (add node:$a, node:$b), node:$a))
    ]
>;

def: Pat<(Frags $a, $b), (ADD $a, $b)>;
```

We would like to add pattern `(set Reg:$dst, (mul reg_or_imm:$src0, (div (add reg_or_imm:$src0, reg_or_imm:$src1), reg_or_imm:$src0)))` for this instruction, then we can use `Pat`:

```tablegen
def : Pat<(set Reg:$dst, (mul reg_or_imm:$src0, (div (add reg_or_imm:$src0, reg_or_imm:$src1), reg_or_imm:$src0))),(ADD reg_or_imm:$src0, reg_or_imm:$src1)>;
```

Also [`PatFrags`](#patfrags) and [`Patfrag`](#Patfrag) can be used in `Pat` to simplify the pattern matching, the following examples are equivalent:

```tablegen
def Frag1: PatFrag<(ops node:$a, node:$b), (add node:$a, node:$b)>;
def Frag2: PatFrag<(ops node:$a, node:$b), (mul (div node:$a, node:$b), node:$a)>;
def: Pat<(Frag1 RegImm:$a, RegImm:$b), (ADD RegImm:$a, RegImm:$b)>;
def: Pat<(Frag2 RegImm:$a, RegImm:$b), (ADD RegImm:$a, RegImm:$b)>;
```

And

```tablegen
def Frags: PatFrags<
    (ops node:$a, node:$b), 
    [
        (add node:$a, node$:b), 
        (mul node:$a, (div (add node:$a, node:$b), node:$a))
    ]
>;

def: Pat<(Frags RegImm:$a, RegImm:$b), (ADD RegImm:$a, RegImm:$b)>;
```

#### Instruction

All instruction definition has sub-class or class of [`Instruction`](llvm-project/llvm/include/llvm/Target/Target.td#L586) and some of the key parameters are:

1. `Namespace`: Name of the target cpu
2. `Size`: Size in byte of encoded instruction, or zero if the size cannot be determined from the opcode
3. `OutOperandList`/`InOperandList`: def/use [DAG](#dag) to list out define and use fo the instruction
   1. Has format of `(ins/outs dag_1:$name_1, dag_2:$name_2, ...)`, here note
   2. Each `dag_i:$name_i` contains a value result from compiling process (different on each program, e.g. different program result in different register allocation, only can be decided while compiling)
   3. By defining variable using name `name_i`, the variable will acquire values result from compiling process
4. `AsmString`: assembly string, using `$name_i` can acquire values result from compiling process (e.g. `st\t$ra, $addr` if allocate `rax` and `0x10000` as operator, it will print out `st\trax, 0x10000`)
5. `pattern`: used in instruction selection: 
   1. Rules out list original DAGs that can be covered by this instruction
   2. Original DAG mainly using operator defined in [TargetSelectionDAG.td](llvm-project/llvm/include/llvm/Target/TargetSelectionDAG.td) with sub-class or class of `class SDNode`
6. `TSFlags`: Value of `TSFlags` field in `MCInstrDesc` c++ class

#### Example1

Using codes in [Cpu0InstrFormats.td](backend_tutorial/chapters/Chapter2/Cpu0InstrFormats.td) and [Cpu0InstrInfo.td](backend_tutorial/chapters/Chapter2/Cpu0InstrInfo.td) as example.

```tablegen
def SDT_Cpu0Ret          : SDTypeProfile<0, 1, [SDTCisInt<0>]>;

// Return
def Cpu0Ret : SDNode<"Cpu0ISD::Ret", SDTNone,
                     [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;
```

The purpose is to define a [DAG operator](#dag-operator), which is `Cpu0Ret`, in order to define a matching `pattern` for return instruction.

The operand type `SDT_Cpu0Ret` I guess is supposed to be the type of `Cpu0Ret`. But for some reason it is not used.

```tablegen
// Signed Operand
def simm16      : Operand<i32> {
  let DecoderMethod= "DecodeSimm16";
}

// Address operand
def mem : Operand<iPTR> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPROut, simm16);
  let EncoderMethod = "getMemEncoding";
}

// Node immediate fits as 16-bit sign extended on target immediate.
// e.g. addi, andi
def immSExt16  : PatLeaf<(imm), [{ return isInt<16>(N->getSExtValue()); }]>;

// Cpu0 Address Mode! SDNode frameindex could possibily be a match
// since load and store instructions from stack used it.
def addr : 
  ComplexPattern<iPTR, 2, "SelectAddr", [frameindex], [SDNPWantParent]>;
```

`simm16` is defined to use as [DAG Operand](#dag-operand) of `InOperandList`, it is defined as `Operand` because it would value a field of record without a concrete value.

`immSExt16` is a [PagLeaf](#patleaf)(DAG without any operand) used in `pattern` of instruction select. It shares the same `name` with `simm16` and the reason of not using `simm16` is that it added a constraint that the node has to be a 16bit int.

Same as `mem` and `addr`, `mem` is defined as [DAG Operand](#dag-operand) for valuing unvalued field. `addr` is actually a [PagLeaf](#patleaf), the reason of not using `mem` is the need of adding complex matching method, which is named `SelectAddr`. They also share the same `name`.

```tablegen
class AlignedLoad<PatFrag Node> :
  PatFrag<(ops node:$ptr), (Node node:$ptr), [{
  LoadSDNode *LD = cast<LoadSDNode>(N);
  return LD->getMemoryVT().getSizeInBits()/8 <= LD->getAlignment();
}]>;

class AlignedStore<PatFrag Node> :
  PatFrag<(ops node:$val, node:$ptr), (Node node:$val, node:$ptr), [{
  StoreSDNode *SD = cast<StoreSDNode>(N);
  return SD->getMemoryVT().getSizeInBits()/8 <= SD->getAlignment();
}]>;

// Load/Store PatFrags.
def load_a          : AlignedLoad<load>;
def store_a         : AlignedStore<store>;
```

Here `load_a` and `store_a` is defined as [PatFrags](#patfrags), which simply added alignment check on the original `load` and `store`.

#### Example2

Using `V_SAT_PK_U8_I16` instruction as example, the definition can be found in 

questions 

1. instruction defined without matching Pattern
2. Using ValueType as DAG node type


### Process

We use the [AMDGPU](#example-amdgpu) example, which runs the selection DAG method.

The entry point is [here](llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp#L590), the target of instruction selection is a function. 

Then calling the following functions:

1. [`SelectAllBasicBlocks`](llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp#L1602) to handle all the blocks within function
2. [`SelectBasicBlock`](llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp#L827) to handle each block
3. [`CodeGenAndEmitDAG`](llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp#L890) to generate first selection DAG, optimizing it and other related work
4. [`DoInstructionSelection`](llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp#L1230) to trigger selection for each instructions
5. 

#### SelectionDAG

LLVM ir will be converted to SelectionDAG, which is a graph of nodes representing the operations in the program.

The following is an example of llvm ir:

```llvm

;Source:
;void test(int a, int b, int *y)
;{
;    *y = a + b;
;}
define dso_local void @test(i32 noundef %a, i32 noundef %b, ptr noundef %y) #0 {
entry:
  %a.addr = alloca i32, align 4
  %b.addr = alloca i32, align 4
  %y.addr = alloca ptr, align 8
  store i32 %a, ptr %a.addr, align 4
  store i32 %b, ptr %b.addr, align 4
  store ptr %y, ptr %y.addr, align 8
  %0 = load i32, ptr %a.addr, align 4
  %1 = load i32, ptr %b.addr, align 4
  %add = add nsw i32 %0, %1
  %2 = load ptr, ptr %y.addr, align 8
  store i32 %add, ptr %2, align 4
  ret void
}
```

The SelectionDAG of the above llvm ir is as follow:

```
SelectionDAG has 23 nodes:
  t0: ch,glue = EntryToken
  t8: i64 = Constant<0>
        t2: i32,ch = CopyFromReg t0, Register:i32 %0
      t10: ch = store<(store (s32) into %ir.a.addr)> t0, t2, FrameIndex:i64<0>, undef:i64
      t4: i32,ch = CopyFromReg t0, Register:i32 %1
    t12: ch = store<(store (s32) into %ir.b.addr)> t10, t4, FrameIndex:i64<1>, undef:i64
    t6: i64,ch = CopyFromReg t0, Register:i64 %2
  t14: ch = store<(store (s64) into %ir.y.addr)> t12, t6, FrameIndex:i64<2>, undef:i64
  t15: i32,ch = load<(dereferenceable load (s32) from %ir.a.addr)> t14, FrameIndex:i64<0>, undef:i64
  t16: i32,ch = load<(dereferenceable load (s32) from %ir.b.addr)> t14, FrameIndex:i64<1>, undef:i64
  t18: i64,ch = load<(dereferenceable load (s64) from %ir.y.addr)> t14, FrameIndex:i64<2>, undef:i64
      t19: ch = TokenFactor t15:1, t16:1, t18:1
      t17: i32 = add nsw t15, t16
    t20: ch = store<(store (s32) into %ir.2)> t19, t17, t18, undef:i64
  t22: ch = X86ISD::RET_GLUE t20, TargetConstant:i32<0>

```

Some points:

1. Each `tn` is a node that represents an operation needed by the program
2. `t12` depends on `t4` may be because if alias happens, `%ir.a.addr` and `%ir.b.addr` would pointing at the same address, then the order of storing matters
3. `t19` is used to synchronize the load of `%ir.a.addr`, `%ir.b.addr` and `%ir.y.addr`


## Register allocation

## Calling convention

Used to define:

1. The order of parameter allocation.
2. Where parameters and return values are placed (that is, on the stack or in registers).
3. Which registers may be used.
4. Whether the caller or callee unwinds the stack.
​​
# 官方教程
    
[地址](https://llvm.org/docs/tutorial/index.html)

[后端生成例子](https://jonathan2251.github.io/lbd/)

# 编译器文档摘要

## 简介

该编译器是一个用于将高级语言代码转换为目标系统汇编代码的工具。它采用了LLVM作为底层技术，并结合了系统调用函数和NPU（神经处理单元）汇编代码的生成，以实现针对特定硬件的优化和执行。

<img src="pic/npu_compiler.drawio.png">

## 软件栈构建

### 概览

软件栈指的是编译器在转换源代码到可执行文件及动态链接库过程中所涉及的所有软件组件。它包括源代码、编译器前端、LLVM中间表示(IR)、后端编译器、系统调用层及最终的目标代码。

### 组件

1. 编译器前端：负责解析高级语言（如C/C++），生成LLVM IR。此阶段包括词法分析、语法分析和语义分析。
2. LLVM IR：一种中间表示，提供了一个与硬件无关的编程模型，可以进行各种优化。
3. 后端编译器：将LLVM IR转换为针对具体硬件（主机CPU及NPU）的汇编代码。
4. 系统调用层：负责处理与操作系统交互，实现对NPU动态链接库的加载和执行。

### 构建过程

1. 源代码到LLVM IR：使用LLVM前端将源代码转换成LLVM IR。
2. LLVM IR到宿主机汇编：将部分LLVM IR转换成适用于宿主机的汇编代码。
3. LLVM IR到NPU汇编：提取特定函数生成NPU汇编，并封装成动态链接库。
4. 链接和装载：将生成的宿主机汇编代码编译链接成可执行文件，将NPU代码编译成动态库。

## 接口

### 编译器命令行接口

命令行参数：支持各种命令行选项，用于控制编译流程、指定输出文件名、定义宏、包含目录等。

示例：

```bash
compiler -source input.c -o output.exe -npu-lib npu_functions.dll
```

### 系统调用接口

1. npu_run函数：用于在运行时加载和执行NPU动态链接库中的代码。
2. 参数与返回值：定义如何传递参数至NPU函数以及如何获取执行结果。
3. 数据传递：通过`COPY_TO_NPU`，`COPY_FROM_NPU`完成与NPU存储之间的数据传递过程
4. 运行监测：特定函数调用接口，用于监测NPU运行状况

## 功能

### 编译功能

编译器的核心功能是将高级语言（如C/C++）编译成能在目标宿主机和从属机（NPU）上运行的代码。这包括以下几个关键步骤和特性：

1. 源代码分析：编译过程首先从源代码的词法分析开始，逐步进行语法分析和语义分析，确保代码符合语言规范。
2. 代码转换：通过编译器前端将源代码转换为LLVM中间表示（IR）。LLVM IR提供了一种高度可优化的形式，能够适应不同目标架构的需求。
3. 代码优化：LLVM 提供了一系列的代码优化工具，如消除冗余代码、循环优化、函数内联等，旨在提高代码执行效率和减小最终生成代码的体积。
4. 目标代码生成：
   1. 宿主机代码生成：编译器将部分LLVM IR针对宿主机的CPU架构（如x86, ARM）转换成机器代码。这一步包括进一步的优化以适应宿主机的硬件特性。
   2. 从属机（NPU）代码生成：对于特定标记或识别的代码段，编译器将其转换成适合NPU执行的指令集。这不仅涉及指令选择，还包括对NPU特性的优化，如并行处理和低能耗操作。

### 保证代码正确性

1. 语义检查：在编译过程中，编译器进行严格的类型检查和语义检查，以确保转换过程中源代码的逻辑一致性，避免如类型不匹配、未定义行为等常见编程错误。
2. 错误与警告报告：编译器提供详尽的错误和警告报告，帮助开发者理解代码中的问题，并指导如何解决。
3. 单元测试和验证工具：支持与外部单元测试和验证工具集成，确保编译的代码在功能上满足原始设计和需求。

### 高级NPU代码优化

针对神经处理单元（NPU）的代码优化是编译器设计中的一项高端技术，旨在充分利用NPU的独特架构和计算能力，以实现超高效的执行性能。


# riscv assembly

```asm
00000000000111b4 <dddddd>:
   111b4: ff010113      addi    sp, sp, -0x10
   111b8: 00113423      sd      ra, 0x8(sp)
   111bc: 00813023      sd      s0, 0x0(sp)
   111c0: 01010413      addi    s0, sp, 0x10
   111c4: 00012537      lui     a0, 0x12
   111c8: 28053603      ld      a2, 0x280(a0)
   111cc: 00000593      li      a1, 0x0
   111d0: 00b60023      sb      a1, 0x0(a2)
   111d4: 28053503      ld      a0, 0x280(a0)
   111d8: 00150513      addi    a0, a0, 0x1
   111dc: 00813083      ld      ra, 0x8(sp)
   111e0: 00013403      ld      s0, 0x0(sp)
   111e4: 01010113      addi    sp, sp, 0x10
   111e8: 00008067      ret
```
1. ``
