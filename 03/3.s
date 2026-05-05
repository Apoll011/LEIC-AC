; Ficheiro:  lab03.s
; Descricao: Programa para a realizacao da 3a atividade laboratorial de
;            Arquitetura de Computadores.
; Autor:     Tiago M Dias (tiago.dias@isel.pt)
; Data:      29-04-2025

; Definicao dos valores dos simbolos utilizados no programa
;
	.equ	STACK_SIZE, 64                ; Dimensao do stack, em bytes

	.equ	ALL_ONES, 0xFFFF              ; Palavra com todos os bits a 1
	.equ	ALL_ZEROS, 0x0000             ; Palavra com todos os bits a 0

	.equ	INPORT_ADDRESS, 0xFF80        ; *** Para completar ***
	.equ	OUTPORT_ADDRESS, 0xFFC0       ; *** Para completar ***

; Seccao:    text
; Descricao: Guarda o codigo do programa
;
	.text
	b	program
	b	.		; Reservado para a ISR
program:        
	ldr	sp, stack_top_addr
	b	main

stack_top_addr:
	.word	stack_top

; Rotina:    main
; Descricao: Inicializa o porto de saída (todos 1s, depois todos 0s) e entra
;            em ciclo contínuo a copiar o valor do porto de entrada para o
;            porto de saída.
; Entradas:  -
; Saidas:    -
; Efeitos:   Ciclo infinito; altera continuamente o porto de saída
main:
	mov	r0, #ALL_ONES & 0xFF
	bl	outport_write
	mov	r0, #ALL_ZEROS & 0xFF
	bl	outport_write
loop:
	bl	inport_read
	bl	outport_write
	b	loop

; Rotina:    inport_read
; Descricao: Adquire e devolve o valor corrente do porto de entrada.
; Entradas:  -
; Saidas:    r0 - valor lido do porto de entrada (8 bits, sem sinal)
; Efeitos:   r1 - endereço do porto de entrada (0xFF80)
inport_read:
	mov	r1, #INPORT_ADDRESS & 0xFF
	movt	r1, #(INPORT_ADDRESS >> 8) & 0xFF
	ldrb	r0, [r1, #0]
	mov	pc, lr


; Rotina:    outport_write
; Descricao: Escreve num porto de saida a 8 bits o valor passado como argumento.
; Entradas:  r0 - valor a escrever no porto de saída (8 bits)
; Saidas:    -
; Efeitos:   r1 - endereço do porto de saída (0xFFC0)
outport_write:
	mov	r1, #OUTPORT_ADDRESS & 0xFF
	movt	r1, #(OUTPORT_ADDRESS >> 8) & 0xFF
	strb	r0, [r1, #0]
	mov	pc, lr

; Rotina:    sleep
; Descricao: Efectua um atraso por software proporcional ao valor de R0.
;            Cada unidade de R0 corresponde a 4992 ciclos de MCLK (~0,1 s).
;            Se R0 = 0, a rotina termina imediatamente.
; Entradas:  r0 - número de iterações do ciclo externo
; Saidas:    -
; Efeitos:   r0 - destruído (fica 0)
;            r1 - destruído (fica 0)
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

; Seccao:    data
; Descricao: Guarda as variaveis globais
;
	.data

; Seccao:    stack
; Descricao: Implementa a pilha com a dimensao definida pelo simbolo STACK_SIZE
;
	.stack
	.space	STACK_SIZE
stack_top:
