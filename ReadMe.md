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

From the [first](#schedule-write-type) and [second](#schedule-read-type) we can analyze that schedule classes `SchedRW = [WriteIMul32RegLd, ReadAfterLd]`.

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

Back to the [example](#example), the `IMUL32rm` instruction needs the following write/read resources:

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

#### Pipeline bypass

#### Machine Model


### Tablegen Definitions
1. Schedule class definition
    ```tablegen
    def ReadAfterLd : SchedRead;

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
2. Instruction definition, this defines schedule class for instructions.
    ```tablegen
    class IMulOpRM_RF<X86TypeInfo t, X86FoldableSchedWrite sched, bit ndd = 0>
    : BinOpRM_RF<0xAF, "imul", t, X86smul_flag, ndd> {
        let Form = MRMSrcMem;
        // `SchedRW` is member of `class Sched`, this mean to rewrite `Sched`
        // According to the content, `sched.Folded = WriteIMul32RegLd` and `sched.ReadAfterFold = ReadAfterLd`
        let SchedRW = [sched.Folded, sched.ReadAfterFold];
    }

    def IMUL32rm : IMulOpRM_RF<Xi32, WriteIMul32Reg>, TB, OpSize32;
    ```
3. Input/Output of instruction:
    ```tablegen
    /*Inputs*/  (ins GR32:$src1, i32mem:$src2)
    /*Output*/  (outs GR32:$dst)
    ```
4. Processor resource definition, this models the processor resources that used by instructions.
    ```tablegen
    // ports
    def SBPort1 : ProcResource<1>;
    def SBPort23 : ProcResource<2>;
    // port groups
    def SBPort01  : ProcResGroup<[SBPort0, SBPort1]>;
    def SBPort15  : ProcResGroup<[SBPort1, SBPort5]>;
    def SBPortAny : ProcResGroup<[SBPort0, SBPort1, SBPort23, SBPort4, SBPort5]> {
        let BufferSize=54;
    }
    ```
5. Write resource definitions, this map schedule class to processor resources and latency.
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
6. Read resource definitions
    ```tablegen
    def : ReadAdvance<ReadAfterLd, 5>;
    ```
7. `SchedMachineModel` definition, this defines chip level schedule properties.
    ```tablegen
    def SandyBridgeModel : SchedMachineModel {
        // All x86 instructions are modeled as a single micro-op, and SB can decode 4
        // instructions per cycle.
        // FIXME: Identify instructions that aren't a single fused micro-op.
        let IssueWidth = 4;
        let MicroOpBufferSize = 168; // Based on the reorder buffer.
        let LoadLatency = 5;
        let MispredictPenalty = 16;

        // Based on the LSD (loop-stream detector) queue size.
        let LoopMicroOpBufferSize = 28;

        // This flag is set to allow the scheduler to assign
        // a default model to unrecognized opcodes.
        let CompleteModel = 0;
    }
    ```
### Explanations for tablegen definitions



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
3. NPU汇编生成：编译器截取LLVM IR中的特定部分，生成针对NPU的汇编代码。此过程包括将特定函数替换为系统调用函数（如npu_run）以启动NPU计算。
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