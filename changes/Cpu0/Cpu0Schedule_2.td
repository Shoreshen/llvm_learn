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
def ALU     : ProcResource<1>{
    /*
        a. BufferSize = -1;
            This means the resource share reseration with CPU (out-of-order processor's instruction buffer).
            A more simple description is that this resource can accept instructions 
            while the CPU's reservation station is not full.

        b. BufferSize = 0;
            This means from the moment, say `t`, of executing an instruction to `t+ReleaseAtCycles` (defined in WriteRes)
            the resource will stop accepting any subsequent instructions that uses this resourece.
            Furthermore, the resource will block the CPU's pipline, 
            meaning CPU's pipline will be hold until the resource is released.

        c. BufferSize = 1;
            This means from the moment, say `t`, of executing an instruction to `t+ReleaseAtCycles` (defined in WriteRes)
            the resource will stop accepting any subsequent instructions that uses this resourece.
            However, the subsequent instructions that uses this resource will be buffered, and CPU pipline will continue to 
            execute other instructions that do not use this resource.
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
    };
    def : WriteRes<II_CLO,      [ALU]>{ 
        let Latency = 1; 
    };
    def : WriteRes<II_CLZ,      [ALU]>{ 
        let Latency = 1; 
    };
    def : WriteRes<IILoad,      [ALU]>{ 
        let Latency = 3; 
    };
    def : WriteRes<IIStore,     [ALU]>{ 
        let Latency = 1; 
    };
    def : WriteRes<IIBranch,    [ALU]>{ 
        let Latency = 1; 
    };
}
