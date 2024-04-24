//===-- Cpu0Schedule.td - Cpu0 Scheduling Definitions ------*- tablegen -*-===//
//
//                    The LLVM Compiler Infrastructure
//
//This file is distributed under the University of Illinois Open Source
//License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Scheduling classes
//===----------------------------------------------------------------------===//
def IIAlu              : SchedWrite;
def II_CLO             : SchedWrite;
def II_CLZ             : SchedWrite;
def IILoad             : SchedWrite;
def IIStore            : SchedWrite;
def IIBranch           : SchedWrite;

//===----------------------------------------------------------------------===//
// machine scheduler
//===----------------------------------------------------------------------===//
def Cpu0genericModel : SchedMachineModel {
    let MicroOpBufferSize = 0;  // in-order processor
    let IssueWidth = 1;         // 1 micro-op per cycle
    let LoadLatency = 1;        // Cycles for loads to access the cache (L1 no miss)
    let MispredictPenalty = 4;  // Branch mis-predict penalty (in cycles)
    bit CompleteModel = 1;      // All instruction has a SchedRW or Instruction itinerary, will report error if not
}

//===----------------------------------------------------------------------===//
// process resources
//===----------------------------------------------------------------------===//
def ALU : ProcResource<1>{
    /*
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
    */
    let BufferSize = 1;
    let SchedModel = Cpu0genericModel;
}
def IMULDIV : ProcResource<1>{
    let BufferSize = 1;
    let SchedModel = Cpu0genericModel;
}

//===----------------------------------------------------------------------===//
// Write resources
//===----------------------------------------------------------------------===//
let SchedModel = Cpu0genericModel in {
    def : WriteRes<IIAlu,       [ALU]>{ 
        let Latency = 1; 
    }
    def : WriteRes<II_CLO,      [ALU]>{ 
        let Latency = 1; 
    }
    def : WriteRes<II_CLZ,      [ALU]>{ 
        let Latency = 1; 
    }
    def : WriteRes<IILoad,      [ALU]>{ 
        let Latency = 3; 
    }
    def : WriteRes<IIStore,     [ALU]>{ 
        let Latency = 1; 
    }
    def : WriteRes<IIBranch,    [ALU]>{ 
        let Latency = 1; 
    }
}
