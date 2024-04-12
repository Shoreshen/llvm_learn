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

```
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

### Schedule Class

This is defined to 

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