# 简介

LLVM的基本流程如下

<img src="pic/5a43a2c1bc664e26a57c4cb4e8b25109.png">

面对不同前后端

<img src="pic/8e397bb56bed55c611de43a02cf1647f.png">

文件流

<img src="pic/fileflow.drawio.png">

# Backend CodeGen

## Tablegen

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

Just a name for different schedule write type, the base class is `SchedWrite`, it is an empty class and defined in `TargetSchedule.td` as follow:

```tablegen
// A target architecture may define SchedReadWrite types and associate
// them with instruction operands.
class SchedReadWrite;
// Define a scheduler resource associated with a def operand.
class SchedWrite : SchedReadWrite;
```

Back to the [example](#example), the `IMUL32rm` instruction's related schedule class are defined as follow:

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

`IMUL32rm`'s schedule wrte type is `WriteIMul32Reg`, whose base classes is `SchedWrite`.

#### Schedule read type

Same as [schedule write type](#schedule-write-type), it just name a type for schedule read type.

The base class is `SchedRead`, it is an empty class and defined in `TargetSchedule.td` as follow:

```tablegen
// A target architecture may define SchedReadWrite types and associate
// them with instruction operands.
class SchedReadWrite;
// Define a scheduler resource associated with a def operand.
class SchedWrite : SchedReadWrite;
```

Back to the [example](#example), the `IMUL32rm` instruction's related schedule class are defined as follow:

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

The major class used in this section are `ProcResource` which defined in `TargetSchedule.td` as follow:

```tablegen
// Define a kind of processor resource that may be common across
// similar subtargets.
class ProcResourceKind;

class ProcResourceUnits<ProcResourceKind kind, int num> {
    ProcResourceKind Kind = kind;
    int NumUnits = num;
    ProcResourceKind Super = ?;
    int BufferSize = -1;
    SchedMachineModel SchedModel = ?;
}

class ProcResource<int num> : ProcResourceKind,
    ProcResourceUnits<!cast<ProcResourceKind>(NAME), num>;
```

Some of the major parameters are:

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

The major class used in this section are `WriteRes` which defined in `TargetSchedule.td` as follow:

```tablegen
class ProcWriteResources<list<ProcResourceKind> resources> {
  list<ProcResourceKind> ProcResources = resources;
  list<int> ReleaseAtCycles = [];
  list<int> AcquireAtCycles = [];
  int Latency = 1;
  int NumMicroOps = 1;
  bit BeginGroup = false;
  bit EndGroup = false;
  bit Unsupported = false;
  bit SingleIssue = false;
  bit RetireOOO = false;
  SchedMachineModel SchedModel = ?;
}

class WriteRes<SchedWrite write, list<ProcResourceKind> resources>
  : ProcWriteResources<resources> {
  SchedWrite WriteType = write;
}
```

Some of the major parameters are:

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

The major class used in this section are `ReadAdvance` which defined in `TargetSchedule.td` as follow:

```tablegen
// Define values common to ReadAdvance and SchedReadAdvance.
//
// SchedModel ties these resources to a processor.
class ProcReadAdvance<int cycles, list<SchedWrite> writes = []> {
  int Cycles = cycles;
  list<SchedWrite> ValidWrites = writes;
  // Allow a processor to mark some scheduling classes as unsupported
  // for stronger verification.
  bit Unsupported = false;
  SchedMachineModel SchedModel = ?;
}

// A processor may define a ReadAdvance associated with a SchedRead
// to reduce latency of a prior write by N cycles. A negative advance
// effectively increases latency, which may be used for cross-domain
// stalls.
//
// A ReadAdvance may be associated with a list of SchedWrites
// to implement pipeline bypass. The Writes list may be empty to
// indicate operands that are always read this number of Cycles later
// than a normal register read, allowing the read's parent instruction
// to issue earlier relative to the writer.
class ReadAdvance<SchedRead read, int cycles, list<SchedWrite> writes = []>
  : ProcReadAdvance<cycles, writes> {
  SchedRead ReadType = read;
}
```

Key parameter is `Cycles`, which means the operand of an instruction will be needed after `n` cycles after the instruction is dispatched.

Back to the [example](#example), the `IMUL32rm` instruction needs the following read resources:

```tablegen
def : ReadAdvance<ReadAfterLd, 5>;
```

From [previous section](#attach-schedule-class-to-instruction), `IMUL32rm` has 2 operands, only the first one has a schedule read type of `ReadAfterLd`

From this we can know that the first operand of `IMUL32rm` will be needed after 5 cycles after the instruction is dispatched.

#### Machine Model

Used to define macro properties of the chip, definitions are as follow:

```tablegen
// Define the SchedMachineModel and provide basic properties for
// coarse grained instruction cost model. Default values for the
// properties are defined in MCSchedModel. A value of "-1" in the
// target description's SchedMachineModel indicates that the property
// is not overriden by the target.
//
// Target hooks allow subtargets to associate LoadLatency and
// HighLatency with groups of opcodes.
//
// See MCSchedule.h for detailed comments.
class SchedMachineModel {
  int IssueWidth = -1; // Max micro-ops that may be scheduled per cycle.
  int MicroOpBufferSize = -1; // Max micro-ops that can be buffered.
  int LoopMicroOpBufferSize = -1; // Max micro-ops that can be buffered for
                                  // optimized loop dispatch/execution.
  int LoadLatency = -1; // Cycles for loads to access the cache.
  int HighLatency = -1; // Approximation of cycles for "high latency" ops.
  int MispredictPenalty = -1; // Extra cycles for a mispredicted branch.

  // Per-cycle resources tables.
  ProcessorItineraries Itineraries = NoItineraries;

  bit PostRAScheduler = false; // Enable Post RegAlloc Scheduler pass.

  // Subtargets that define a model for only a subset of instructions
  // that have a scheduling class (itinerary class or SchedRW list)
  // and may actually be generated for that subtarget must clear this
  // bit. Otherwise, the scheduler considers an unmodelled opcode to
  // be an error. This should only be set during initial bringup,
  // or there will be no way to catch simple errors in the model
  // resulting from changes to the instruction definitions.
  bit CompleteModel = true;

  // Indicates that we should do full overlap checking for multiple InstrRWs
  // defining the same instructions within the same SchedMachineModel.
  // FIXME: Remove when all in tree targets are clean with the full check
  // enabled.
  bit FullInstRWOverlapCheck = true;

  // A processor may only implement part of published ISA, due to either new ISA
  // extensions, (e.g. Pentium 4 doesn't have AVX) or implementation
  // (ARM/MIPS/PowerPC/SPARC soft float cores).
  //
  // For a processor which doesn't support some feature(s), the schedule model
  // can use:
  //
  // let<Predicate> UnsupportedFeatures = [HaveA,..,HaveY];
  //
  // to skip the checks for scheduling information when building LLVM for
  // instructions which have any of the listed predicates in their Predicates
  // field.
  list<Predicate> UnsupportedFeatures = [];

  bit NoModel = false; // Special tag to indicate missing machine model.

  // Tells the MachineScheduler whether or not to track resource usage
  // using intervals via ResourceSegments (see
  // llvm/include/llvm/CodeGen/MachineScheduler.h).
  bit EnableIntervals = false;
}
```

Some of the key parameters are:

1. `MicroOpBufferSize` size of reservation station, if `MicroOpBufferSize = 0` then in-order processor
2. `IssueWidth` number of micro-ops can be issued per-cycle.
3. `LoadLatency` Cycles for loads to access the cache (L1 no miss)
4. `MispredictPenalty` Branch mis-predict penalty (in cycles)
5. `CompleteModel` if is `true`, then all instruction has a SchedRW or Instruction itinerary, will report error if not

### Source code and related structures

## Instruction Define


# 官方教程
    
[地址](https://llvm.org/docs/tutorial/index.html)

[后端生成例子](https://jonathan2251.github.io/lbd/)

# 编译器文档摘要

## 简介

该编译器是一个用于将高级语言代码转换为目标系统汇编代码的工具。它采用了LLVM作为底层技术，并结合了系统调用函数和NPU（神经处理单元）汇编代码的生成，以实现针对特定硬件的优化和执行。

<img src="pic/npu_compiler.drawio.png">

## 编译流程

1. 高级语言代码输入：用户提供高级语言代码，通常是C/C++或类似语言。
2. LLVM IR生成：编译器将高级语言代码转换为LLVM IR（Intermediate Representation），利用LLVM工具链进行处理。
3. NPU汇编生成：编译器截取LLVM IR中的特定部分，生成针对NPU的汇编代码。此过程包括将特定代码段（`begine_run_loop`到`end_run_loop`）替换为系统调用函数（如npu_run）以启动NPU计算。
4. 宿主机汇编生成：剩余的LLVM IR代码转换为宿主机（Host）系统的汇编代码，以在主机CPU上执行。
5. 可执行文件生成：LLVM工具链中的LLC工具将宿主机汇编代码转换为可执行文件，用于主机CPU执行。
6. 动态链接库生成：NPU汇编代码转换为动态链接库（DLL），以供主机系统在运行时载入。

## 运行流程

1. 主机系统调用：在运行时，主机系统调用特定的系统调用函数（如npu_run）以载入NPU动态链接库。
2. NPU代码加载：系统获取NPU汇编函数的地址和长度，并将代码加载到NPU的存储器上进行执行。

## 优化与定制

该编译器可根据特定硬件的需求进行优化和定制，包括但不限于：

1. 针对NPU的优化：生成特定的NPU汇编代码以充分利用NPU的计算能力。
2. 主机系统优化：生成高效的宿主机汇编代码，以确保在主机CPU上的高性能执行。
3. 系统调用定制：根据需要定制系统调用函数，以适配不同的主机系统和操作系统环境。

## 注意事项

1. 用户应确保高级语言代码的兼容性和正确性，以确保编译器的正确工作。
2. 对于定制化需求，用户应参考相关文档进行适当的配置和调整。
3. 在运行时，需确保主机系统具有正确的权限以加载和执行动态链接库。