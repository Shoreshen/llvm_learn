# Instruction Definitions

Using the example of instruction `V_XNOR_B32`

## Pseudo Instruction

1. Seems like architecture independent instruction
2. By applying `multiclass VOP2Inst`, various types of instruction will be generated including `e23`, `e64`, `dpp`, `sdwa` and `e64_dpp`
3. By applying different layers of `class`, it separates the dealing of number of source, instruction type and finally generate `class VOP_Pseudo`
4. One of the key parameter is `VOPProfile`, which controlling the generation process of various types of instructions, and creating in/out operand list, wether to generate patterns or not, etc.
5. Pseudo instruction does not include instruction encodings.
6. For pattern, only `V_XNOR_B32_e64` has the pattern of `[(set i32:$vdst, (xnor i32:$src0, i32:$src1))]`, all other pseudo instructions has empty pattern (`pattern = []`) on definition

## Real Instruction

1. Used to define instructions for different architectures (gfx10, gfx11, gfx12, etc.)
2. Each architecture also has different type of instructions, such as `e23`, `e64`, `dpp`, `sdwa` and `e64_dpp`. It is not necessary that each architecture will contain all the above types
3. Multi classes are used to control the generation of different types and architectures of instructions
4. Real instruction will be generated based on Pseudo instruction, will reuse information from Pseudo instruction, such as `OutOperandList`, `InOperandList`, `AsmOperands`, etc.
5. For pattern, all real instructions has empty pattern (`pattern = []`) on definition

## GCNPat

Defined as follow:

```tablegen
class GCNPat<dag pattern, dag result> : Pat<pattern, result>, PredicateControl;
```

Which is a version of `Pat` with predicates. Patterns of `V_XNOR_B32_e64` is defined us `GCNPat`.
