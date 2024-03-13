# 简介

LLVM的基本流程如下

<img src="pic/5a43a2c1bc664e26a57c4cb4e8b25109.png">

面对不同前后端

<img src="pic/8e397bb56bed55c611de43a02cf1647f.png">

文件流

<img src="pic/fileflow.drawio.png">

# Backend CodeGen

## Setting up

### Files to modify

1. `llvm/include/llvm/ADT/Triple.h`

## Tablegen

### 指令

必须继承`llvm-project/llvm/include/llvm/Target/Target.td`目录下的`class InstrItinClass`类，主要包括以下几个元素：

| 元素 | 说明 |
| --- | --- |
| `InstrItinClass` | 是一个空白的类，只用于归类`InstrItinData`|
| `InstrItinData` | 用于描述指令的执行流程 |

```c++
class Bypass;
class InstrStage<
    int cycles, 
    list<FuncUnit> units,
    int timeinc = -1,
    ReservationKind kind = Required
> {
    int Cycles           = cycles;       // length of stage in machine cycles
    list<FuncUnit> Units = units;        // choice of functional units
    int TimeInc          = timeinc;      // cycles till start of next stage
    int Kind             = kind.Value;   // kind of FU reservation
}
class InstrItinClass;
class InstrItinData<
    InstrItinClass Class, 
    list<InstrStage> stages,
    list<int> operandcycles = [],
    list<Bypass> bypasses = [], int uops = 1
> {
    InstrItinClass TheClass = Class;
    int NumMicroOps = uops;
    list<InstrStage> Stages = stages;
    list<int> OperandCycles = operandcycles;
    list<Bypass> Bypasses = bypasses;
}
classInstruction:InstructionEncoding{
    stringNamespace="";
    dagOutOperandList;
    dagInOperandList;
    stringAsmString="";
    EncodingByHwModeEncodingInfos;
    list<dag>Pattern;
    list<Register>Uses=[];
    list<Register>Defs=[];
    list<Predicate>Predicates=[];
    intSize=0;
    intCodeSize=0;
    intAddedComplexity=0;
    bitisPreISelOpcode=false;
    bitisReturn=false;
    bitisBranch=false;
    bitisEHScopeReturn=false;
    bitisIndirectBranch=false;
    bitisCompare=false;
    bitisMoveImm=false;
    bitisMoveReg=false;
    bitisBitcast=false;
    bitisSelect=false;
    bitisBarrier=false;
    bitisCall=false;
    bitisAdd=false;
    bitisTrap=false;
    bitcanFoldAsLoad=false;
    bitmayLoad=?;
    bitmayStore=?;
    bitmayRaiseFPException=false;
    bitisConvertibleToThreeAddress=false;
    bitisCommutable=false;
    bitisTerminator=false;
    bitisReMaterializable=false;
    bitisPredicable=false;
    bitisUnpredicable=false;
    bithasDelaySlot=false;
    bitusesCustomInserter=false;
    bithasPostISelHook=false;
    bithasCtrlDep=false;
    bitisNotDuplicable=false;
    bitisConvergent=false;
    bitisAuthenticated=false;
    bitisAsCheapAsAMove=false;
    bithasExtraSrcRegAllocReq=false;
    bithasExtraDefRegAllocReq=false;
    bitisRegSequence=false;
    bitisPseudo=false;
    bitisMeta=false;
    bitisExtractSubreg=false;
    bitisInsertSubreg=false;
    bitvariadicOpsAreDefs=false;
    bithasSideEffects=?;
    bitisCodeGenOnly=false;
    bitisAsmParserOnly=false;
    bithasNoSchedulingInfo=false;
    InstrItinClassItinerary=NoItinerary;
    list<SchedReadWrite>SchedRW;
    stringConstraints="";
    stringDisableEncoding="";
    stringPostEncoderMethod="";
    bits<64>TSFlags=0;
    stringAsmMatchConverter="";
    stringTwoOperandAliasConstraint="";
    stringAsmVariantName="";
    bitUseNamedOperandTable=false;
    bitUseLogicalOperandMappings=false;
    bitFastISelShouldIgnore=false;
    bitHasPositionOrder=false;
}
```

# 官方教程
    
[地址](https://llvm.org/docs/tutorial/index.html)

[后端生成例子](https://jonathan2251.github.io/lbd/)