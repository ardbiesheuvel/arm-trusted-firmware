/*
 * Copyright (c) 2017, ARM Limited and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <arch.h>
#include <asm_macros.S>
#include <common/bl_common.h>
#include <context.h>
#include <pl011.h>

/* -----------------------------------------------------------------------------
 * Very simple stackless exception handlers used by the spm shim layer.
 * -----------------------------------------------------------------------------
 */
	.globl	spm_shim_exceptions_ptr

vector_base spm_shim_exceptions_ptr, .spm_shim_exceptions

	/* -----------------------------------------------------
	 * Current EL with SP0 : 0x0 - 0x200
	 * -----------------------------------------------------
	 */
vector_entry SynchronousExceptionSP0, .spm_shim_exceptions
	b	.
end_vector_entry SynchronousExceptionSP0

vector_entry IrqSP0, .spm_shim_exceptions
	b	.
end_vector_entry IrqSP0

vector_entry FiqSP0, .spm_shim_exceptions
	b	.
end_vector_entry FiqSP0

vector_entry SErrorSP0, .spm_shim_exceptions
	b	.
end_vector_entry SErrorSP0

	/* -----------------------------------------------------
	 * Current EL with SPx: 0x200 - 0x400
	 * -----------------------------------------------------
	 */
vector_entry SynchronousExceptionSPx, .spm_shim_exceptions
	b	.
end_vector_entry SynchronousExceptionSPx

vector_entry IrqSPx, .spm_shim_exceptions
	b	.
end_vector_entry IrqSPx

vector_entry FiqSPx, .spm_shim_exceptions
	b	.
end_vector_entry FiqSPx

vector_entry SErrorSPx, .spm_shim_exceptions
	b	.
end_vector_entry SErrorSPx

	/* -----------------------------------------------------
	 * Lower EL using AArch64 : 0x400 - 0x600. No exceptions
	 * are handled since secure_partition does not implement
	 * a lower EL
	 * -----------------------------------------------------
	 */
vector_entry SynchronousExceptionA64, .spm_shim_exceptions
	msr	tpidr_el1, x30
	mrs	x30, esr_el1
	ubfx	x30, x30, #ESR_EC_SHIFT, #ESR_EC_LENGTH

	cmp	x30, #EC_AARCH64_SVC
	b.eq 	do_smc

	cmp	x30, #EC_AARCH32_SVC
	b.eq	do_smc

	cmp	x30, #EC_AARCH64_SYS
	b.eq	handle_sys_trap

	/* Fail in all the other cases */
	b	panic

	/* ---------------------------------------------
	 * Tell SPM that we are done initialising
	 * ---------------------------------------------
	 */
do_smc:
	mrs	x30, tpidr_el1
	smc	#0
	eret

	/* AArch64 system instructions trap are handled as a panic for now */
panic:
	mov_imm	x1, 0x2A400000

	adr	x4, esr_el1_str
	bl	asm_print_str

	mrs	x4, esr_el1
	bl	asm_print_hex

	adr	x4, elr_el1_str
	bl	asm_print_str

	mrs	x4, elr_el1
	bl	asm_print_hex

	adr	x4, far_el1_str
	bl	asm_print_str

	mrs	x4, far_el1
	bl	asm_print_hex

handle_sys_trap:
	wfi
	b	handle_sys_trap
end_vector_entry SynchronousExceptionA64

vector_entry IrqA64, .spm_shim_exceptions
	b	.
end_vector_entry IrqA64

vector_entry FiqA64, .spm_shim_exceptions
	b	.
end_vector_entry FiqA64

vector_entry SErrorA64, .spm_shim_exceptions
	b	.
end_vector_entry SErrorA64

	/* -----------------------------------------------------
	 * Lower EL using AArch32 : 0x600 - 0x800
	 * -----------------------------------------------------
	 */
vector_entry SynchronousExceptionA32, .spm_shim_exceptions
	b	.
end_vector_entry SynchronousExceptionA32

vector_entry IrqA32, .spm_shim_exceptions
	b	.
end_vector_entry IrqA32

vector_entry FiqA32, .spm_shim_exceptions
	b	.
end_vector_entry FiqA32

vector_entry SErrorA32, .spm_shim_exceptions
	b	.
end_vector_entry SErrorA32

asm_print_str:
	mov	x3, x30
1:
	ldrb	w0, [x4], #0x1
	cbz	x0, 2f
	bl	__console_pl011_core_putc
	b	1b
2:
	ret	x3

/*
 * This function prints a hexadecimal number in x4.
 * In: x4 = the hexadecimal to print.
 * Clobber: x30, x0 - x3, x5
 */
 asm_print_hex:
	mov	x3, x30
	mov	x5, #64  /* No of bits to convert to ascii */
1:
	sub	x5, x5, #4
	lsrv	x0, x4, x5
	and	x0, x0, #0xf
	cmp	x0, #0xA
	b.lo	2f
	/* Add by 0x27 in addition to ASCII_OFFSET_NUM
	 * to get ascii for characters 'a - f'.
	 */
	add	x0, x0, #0x27
2:
	add	x0, x0, #'0'
	bl	__console_pl011_core_putc
	cbnz	x5, 1b
	ret	x3

__console_pl011_core_putc:
	/* Prepend '\r' to '\n' */
	cmp	w0, #0xA
	b.ne	2f
1:
	/* Check if the transmit FIFO is full */
	ldr	w2, [x1, #UARTFR]
	tbnz	w2, #PL011_UARTFR_TXFF_BIT, 1b
	mov	w2, #0xD
	str	w2, [x1, #UARTDR]
2:
	/* Check if the transmit FIFO is full */
	ldr	w2, [x1, #UARTFR]
	tbnz	w2, #PL011_UARTFR_TXFF_BIT, 2b
	str	w0, [x1, #UARTDR]
	ret

	.align	2
esr_el1_str:
	.asciz "\nESR_EL1:  "
	.align	2
elr_el1_str:
	.asciz "\nELR_EL1:  "
	.align	2
far_el1_str:
	.asciz "\nFAR_EL1:  "
