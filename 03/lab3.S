; Ficheiro:  lab03.s
; Descricao: Programa para a realizacao da 3a atividade laboratorial de
;            Arquitetura de Computadores.
; Autor:	 Tiago Inês & Abdelhak Ould Chikr 
; Data:      05-04-2026

; Definicao dos valores dos simbolos utilizados no programa
;
	.equ	STACK_SIZE, 64                ; Dimensao do stack, em bytes

	.equ	ALL_ONES, 0xFFFF              ; Palavra com todos os bits a 1
	.equ	ALL_ZEROS, 0x0000             ; Palavra com todos os bits a 0

	.equ	INPORT_ADDRESS, 0xFF80 
	.equ	OUTPORT_ADDRESS, 0xFFC0

	.text
	b	program
	b	.
program:        
	ldr	sp, stack_top_addr
	b	main

stack_top_addr:
	.word	stack_top

main:
	mov	r0, #ALL_ONES & 0xFF
	bl	outport_write
	mov	r0, #ALL_ZEROS & 0xFF
	bl	outport_write
	mov r4, #0x07
loop:
	;bl	inport_read
	bl inport_read
	and r0, r0, r4
	add r0, r0, #1
	lsl r1, r0, #3
	lsl r2, r0, #1
	add r2, r2, r1
	lsr r2, r2, #1
	mov r0, #0x81
	bl	outport_write
	mov r0, r2
	bl sleep
	mov r0, #0x80
	bl	outport_write
	mov r0, r2
	bl sleep
	b	loop

; Rotina:    inport_read
; Descricao: Adquire e devolve o valor corrente do porto de entrada.
inport_read:
	mov	r1, #INPORT_ADDRESS & 0xFF
	movt	r1, #(INPORT_ADDRESS >> 8) & 0xFF
	ldrb	r0, [r1, #0]
	mov	pc, lr

; Rotina:    outport_write
; Descricao: Escreve num porto de saida a 8 bits o valor passado como argumento.
outport_write:
	mov	r1, #OUTPORT_ADDRESS & 0xFF
	movt	r1, #(OUTPORT_ADDRESS >> 8) & 0xFF
	strb	r0, [r1, #0]
	mov	pc, lr

sleep:
	and	r0, r0, r0
	beq	sleep_end
sleep_outer_loop:
	mov	r1, #0x3E
	movt	r1, #0x03
sleep_inner_loop:
	sub	r1, r1, #1
	bne	sleep_inner_loop
	sub	r0, r0, #1
	bne	sleep_outer_loop
sleep_end:
	mov	pc, lr

	.data
	.word 11

	.stack
	.space	STACK_SIZE
stack_top:

; r0++, r0<<3 + r0<<1
; 000 - 0x0A  0 - 10
; 001 - 0x14  1 - 20
; 010 - 0x1E  2 - 30
; 011 - 0x28  40
; 100 - 0x32  50
; 101 - 0x3C  60
; 110 - 0x46  70
; 111 - 0x50  80
