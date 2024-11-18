	.text
	.amdgcn_target "amdgcn-amd-amdhsa--gfx700"
	.amdhsa_code_object_version 5
	.protected	_Z10vector_addPfS_S_i   ; -- Begin function _Z10vector_addPfS_S_i
	.globl	_Z10vector_addPfS_S_i
	.p2align	8
	.type	_Z10vector_addPfS_S_i,@function
_Z10vector_addPfS_S_i:                  ; @_Z10vector_addPfS_S_i
; %bb.0:                                ; %entry
	s_load_dword s0, s[4:5], 0x2c
	s_waitcnt lgkmcnt(0)
	s_and_b32 s0, s0, 0xffff
	s_mul_i32 s6, s6, s0
	v_add_u32_e32 v0, s6, v0
	s_mov_b32 s0, 0xf4240
	v_cmp_gt_i32_e32 vcc, s0, v0
	s_and_saveexec_b64 s[0:1], vcc
	s_cbranch_execz .LBB0_2
; %bb.1:                                ; %if.then
	s_load_dwordx2 s[6:7], s[4:5], 0x10
	s_load_dwordx4 s[0:3], s[4:5], 0x0
	v_ashrrev_i32_e32 v1, 31, v0
	v_lshlrev_b64 v[0:1], 2, v[0:1]
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v3, s7
	v_add_co_u32_e32 v2, vcc, s6, v0
	v_addc_co_u32_e32 v3, vcc, v3, v1, vcc
	v_mov_b32_e32 v5, s3
	v_add_co_u32_e32 v4, vcc, s2, v0
	v_addc_co_u32_e32 v5, vcc, v5, v1, vcc
	global_load_dword v6, v[4:5], off
	global_load_dword v7, v[2:3], off
	v_mov_b32_e32 v2, s1
	v_add_co_u32_e32 v0, vcc, s0, v0
	v_addc_co_u32_e32 v1, vcc, v2, v1, vcc
	s_waitcnt vmcnt(0)
	v_add_f32_e32 v2, v6, v7
	global_store_dword v[0:1], v2, off
.LBB0_2:                                ; %if.end
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel _Z10vector_addPfS_S_i
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 288
		.amdhsa_user_sgpr_count 6
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 0
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 0
		.amdhsa_user_sgpr_flat_scratch_init 0
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 0
		.amdhsa_system_sgpr_private_segment_wavefront_offset 0
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 0
		.amdhsa_system_sgpr_workgroup_id_z 0
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 0
		.amdhsa_next_free_vgpr 8
		.amdhsa_next_free_sgpr 8
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_flat_scratch 0
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end0:
	.size	_Z10vector_addPfS_S_i, .Lfunc_end0-_Z10vector_addPfS_S_i
                                        ; -- End function
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 152
; NumSgprs: 10
; NumVgprs: 8
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 1
; VGPRBlocks: 1
; NumSGPRsForWavesPerEU: 10
; NumVGPRsForWavesPerEU: 8
; Occupancy: 8
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 6
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
	.protected	_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE ; @_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE
	.type	_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE,@object
	.section	.rodata._ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE,"aG",@progbits,_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE,comdat
	.weak	_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE
_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE:
	.zero	1
	.size	_ZN17__HIP_CoordinatesI14__HIP_BlockDimE1xE, 1

	.protected	_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE ; @_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE
	.type	_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE,@object
	.section	.rodata._ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE,"aG",@progbits,_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE,comdat
	.weak	_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE
_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE:
	.zero	1
	.size	_ZN17__HIP_CoordinatesI14__HIP_BlockIdxE1xE, 1

	.protected	_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE ; @_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE
	.type	_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE,@object
	.section	.rodata._ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE,"aG",@progbits,_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE,comdat
	.weak	_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE
_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE:
	.zero	1
	.size	_ZN17__HIP_CoordinatesI15__HIP_ThreadIdxE1xE, 1

	.type	__hip_cuid_319e2ae05f154ea5,@object ; @__hip_cuid_319e2ae05f154ea5
	.section	.bss,"aw",@nobits
	.globl	__hip_cuid_319e2ae05f154ea5
__hip_cuid_319e2ae05f154ea5:
	.byte	0                               ; 0x0
	.size	__hip_cuid_319e2ae05f154ea5, 1

	.ident	"clang version 19.1.4 (git@github.com:llvm/llvm-project.git d174e2a5538984bca3d31ac41aff71528bb28747)"
	.ident	"clang version 17.0.0"
	.section	".note.GNU-stack","",@progbits
	.amdgpu_metadata
---
amdhsa.kernels:
  - .args:
      - .address_space:  global
        .name:           c.coerce
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .name:           a.coerce
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .name:           b.coerce
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .name:           !str n
        .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         36
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         40
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         44
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         46
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         48
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         50
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         52
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         54
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         80
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         88
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         96
        .size:           2
        .value_kind:     hidden_grid_dims
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 288
    .language:       OpenCL C
    .language_version:
      - 2
      - 0
    .max_flat_workgroup_size: 1024
    .name:           _Z10vector_addPfS_S_i
    .private_segment_fixed_size: 0
    .sgpr_count:     10
    .sgpr_spill_count: 0
    .symbol:         _Z10vector_addPfS_S_i.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     8
    .vgpr_spill_count: 0
    .wavefront_size: 64
amdhsa.target:   amdgcn-amd-amdhsa--gfx700
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
