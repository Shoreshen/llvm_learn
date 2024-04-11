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

### Related Definition

Instruction definition:

```
class BinOpRM<bits<8> o, string m, string args, X86TypeInfo t, dag out, list<dag> p>
  : ITy<o, MRMSrcMem, t, out, (ins t.RegClass:$src1, t.MemOperand:$src2), m,
        args, p>,
    Sched<[WriteALU.Folded, WriteALU.ReadAfterFold]> {
  let mayLoad = 1;
}

class BinOpRM_RF<bits<8> o, string m, X86TypeInfo t, SDPatternOperator node, bit ndd = 0>
  : BinOpRM<o, m, !if(!eq(ndd, 0), binop_args, binop_ndd_args), t, (outs t.RegClass:$dst),
            [(set t.RegClass:$dst, EFLAGS, (node t.RegClass:$src1,
             (t.LoadNode addr:$src2)))]>, DefEFLAGS, NDD<ndd>;

class IMulOpRM_RF<X86TypeInfo t, X86FoldableSchedWrite sched, bit ndd = 0>
  : BinOpRM_RF<0xAF, "imul", t, X86smul_flag, ndd> {
  let Form = MRMSrcMem;
  let SchedRW = [sched.Folded, sched.ReadAfterFold];
}

def IMUL32rm : IMulOpRM_RF<Xi32, WriteIMul32Reg>, TB, OpSize32;
```



## Instruction Define


# 官方教程
    
[地址](https://llvm.org/docs/tutorial/index.html)

[后端生成例子](https://jonathan2251.github.io/lbd/)