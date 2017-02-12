// To keep this in the first portion of the binary.
.section .text.boot
 
// Make _start global.
.globl _start
.globl enable_irq
.globl enable_fiq
.globl disable_irq
.globl disable_fiq
// Entry point for the kernel.
// r15 -> should begin execution at 0x8000.
// r0 -> 0x00000000
// r1 -> 0x00000C42
// r2 -> 0x00000100 - start of ATAGS
// preserve these registers as argument for kernel_main
_start:
        ldr pc, _reset_handler_h			
        ldr pc, _undefined_instruction_handler_h
        ldr pc, _software_interrupt_handler_h
        ldr pc, _prefetch_abort_handler_h
        ldr pc, _data_abort_handler_h
        ldr pc, _unused_handler_h
        ldr pc, _interrupt_handler_h
        ldr pc, _fast_interrupt_handler_h

_reset_handler_h:                    .word   _reset
_undefined_instruction_handler_h:    .word   undefined_instruction_interrupt_handler
_software_interrupt_handler_h:       .word   bad_interrupt_handler
_prefetch_abort_handler_h:           .word   bad_interrupt_handler
_data_abort_handler_h:               .word   data_abort_interrupt_handler
_unused_handler_h:                   .word   _reset
_interrupt_handler_h:                .word   irq_interrupt_handler
_fast_interrupt_handler_h:           .word   fiq_interrupt_handler


irq_interrupt_handler:
	// Saving state and rewinding the stack
	sub lr, #4
	stmfd sp!, {r0-r3, r12, lr}
	b disable_irq
	// C handler
	b irq_interrupt_handler_c
	b enable_irq
	// Restoring everything then return to the program
	ldmfd sp!, {r0-r3, r12, pc}


.equ Usr32md, 0x10
.equ FIQ32md, 0x11
.equ IRQ32md, 0x12
.equ SVC32md, 0x13
.equ Abt32md, 0x17
.equ Und32md, 0x1b
.equ Sys32md, 0x1f

.equ USR_Stack, 0x20000
.equ IRQ_Stack, 0x8000	
.equ SVC_Stack, IRQ_Stack-128

_reset:	
	// Move the interrupt table to 0x00
        ldr     r0, =_start
        mov     r1, #0x00
	
	ldmia   r0!,{r2, r3, r4, r5, r6, r7, r8, r9}
	stmia   r1!,{r2, r3, r4, r5, r6, r7, r8, r9}

	//   r0 = _start + 0x20
	//   r1 = 0x20
        ldmia   r0!,{r2, r3, r4, r5, r6, r7, r8, r9}
        stmia   r1!,{r2, r3, r4, r5, r6, r7, r8, r9}

	// Setup the different stacks.
	// SVC stack
	ldr r0,=SVC32md
	msr cpsr_c,r0
	ldr r13,=SVC_Stack

	// IRQ stack
	ldr r0,=IRQ32md
	msr cpsr_c,r0
	ldr r13,=IRQ_Stack

	// USR Stack
	ldr r0,=Usr32md
	msr cpsr_c,r0
	ldr r13,=USR_Stack
	
	
	// Clear out bss.
	ldr r4, =__bss_start
	ldr   r9, =__bss_end
	mov           r5, #0
	mov           r6, #0
	mov           r7, #0
	mov           r8, #0	
	b                 2f

	
1:
	// store multiple at r4.
	stmia r4!, {r5-r8}
	
	// If we are still below bss_end, loop.
2:
	cmp r4, r9
	blo 1b
 
	// Call kernel_main on the C side
	ldr r3, = kernel_main
	blx r3
 
// halt
halt:
	wfe
	b halt

enable_irq:
	mrs r1,cpsr
	bic r1,r1,#0x80
	msr cpsr_c, r1
	bx lr

disable_irq:
	mrs r1,cpsr
	orr r1,r1,#0x80
	msr cpsr_c, r1
	bx lr

enable_fiq:
	mrs r1,cpsr
	bic r1,r1,#0x40
	msr cpsr_c, r1
	bx lr
	
disable_fiq:
	mrs r1,cpsr
	orr r1,r1,#0x40
	msr cpsr_c, r1
	bx lr
	
.globl enable_mmu
enable_mmu:
	;@ Invalidate TLB
	mcr p15, 0, r2, c8, c7, 0

	;@ Setting the tlb base
	mov r2,#0
	mcr p15, 0, r2, c2, c0, 2  ;@ Write Translation Table Base Control Register.
	mcr p15,0,r0,c2,c0,0	   ;@ Write Translation Table Base Register 0.
	
	;@ Setting up Domain Access Control Register
	mcr p15,0,r1,c3,c0,0

	;@ Activate MMU
	mrc p15,0,r2,c1,c0,0  ;@ loading CP15
	orr r2,r2,#0x1         ;@ setting enabling MMU bit
	mcr p15,0,r2,c1,c0,0  ;@ saving

	bx lr

.globl read_cp15
read_cp15:
	mrc p15,0,r2,c1,c0,0 ;@ loading CP15
	bx lr
	
.globl reset_cp15	
reset_cp15:
	mvn r0, #0x0
	mcr p15,0,r0,c1,c0,0 ;@ saving
	bx lr
	
.globl loop
loop:
	b loop
