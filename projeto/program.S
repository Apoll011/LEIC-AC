; Ficheiro:  Projeto.S
; Descricao: Trabalho prático para a disciplina de Arquitetura de Computadores
; Autor:     A54193 & A53107
; Data:      5-10-2026

    .equ	STACK_SIZE, 	64

	.equ	ALL_ONES,		0xFFFF
	.equ	ALL_ZEROS, 		0x0000

	.equ	INPORT_ADDRESS, 0xFF80
	.equ	OUTPORT_ADDRESS,0xFFC0

    .equ    LED0_MASK,		0x01
    .equ    LED1_MASK,		0x02
    .equ    LED2_MASK,		0x04
    .equ    LED3_MASK,		0x08

    .equ	LED_BLACK,		0x00
    .equ    LED_RED,		0x01
    .equ    LED_GREEN,	 	0x02
    .equ    LED_YELLOW, 	0x03
	.equ 	ALL_LEDS, 		LED0_MASK | LED1_MASK | LED2_MASK | LED3_MASK

	.equ  	PTC_BASE,     	0xFF00
    .equ  	PTC_TCR,      	0x00
	.equ  	PTC_TMR,      	0x02
    .equ  	PTC_TC,       	0x04
    .equ  	PTC_TIR,      	0x06

.text
	b		program
	b		ptc_isr

program:
	ldr		sp, stack_top_addr
	b		main

stack_top_addr:
	.word	stack_top

; --------------- Game Logic ----------------------
main:
	bl ptc_init

	; Enable Interrupts
	mrs		r0, cpsr
	mov		r1, #0x0010
	orr		r0, r0, r1
	msr		cpsr, r0
	
	reset:
	; Initial LED sequence
    mov 	r0, #ALL_LEDS
    bl 		clear

	mov 	r0, #ALL_LEDS
    mov 	r1, #LED_YELLOW
    bl 		led
    
	wait_for_startup:
		bl	check_buttons

		and r0, r0, r0
		bzs wait_for_startup

		mov r0, #ALL_LEDS
		bl	clear

		mov r4, #0x01
		mov r5, #0

	wait_game_start:
		add r5, r5, #1

		bl	check_buttons

		cmp r0, r4
		bne wait_game_start
		
		and r5, r5, r5
		bzc	pre_game
		
		mov r0, r5

	pre_game:
		bl	init_random

game_starts:
	push	lr

	mov 	r0, #0
	ldr 	r1, round_addr
	strb 	r0, [r1, #0]

	mov		r1, #0b11100000
	bl 		inport_read
	and 	r0, r0, r1
	lsr 	r0, r0, #5

	mov 	r1, #10
	sub 	r5, r1, r0

main_while:
;r4 = round
;r5 = time
;r6 = current moles
	ldr 	r1, round_addr
	ldrb 	r4, [r1, #0]


	lsr 	r3, r5, #3
	lsr 	r5, r5, #1
	add 	r5, r5, r3
	mov 	r0, r5
	bl      ptc_start

	
	ldr 	r1, moles_addr
	ldrb 	r6, [r1, r4]
	
	mov 	r0, r6
	mov 	r1, #LED_GREEN
	bl 		led

round_while:

	and 	r6, r6, r6
	bzs 	round_while_end

	bl      check_buttons
	and 	r0, r6, r0

	eor 	r6, r6, r0

	mov 	r1, #LED_RED
	bl 		led

	bl      ptc_done
	and 	r0, r0, r0
	bzc 	round_while

round_while_end:

	and 	r6, r6, r6
	bzc 	main_while_end

	mov 	r0, #ALL_LEDS
	bl 		clear

	mov 	r0, #5
	bl 		sleep

	add 	r4, r4, #1
	ldr 	r1, round_addr
	strb 	r4, [r1, #0]

	mov 	r5, #9
	cmp 	r5, r4
	bge     main_while

main_while_end:
		
    cmp  r5, r4
    bge  game_lost
    b    game_won
	

round_addr:
	.word round
moles_addr:
	.word Mole_test


game_won:
	mov		r0, #LED_GREEN
	mov		r1, #5
	bl 		blink
	
	mov		r0, #LED_GREEN
	mov		r1, #5
	bl 		blink

	mov		r0, #LED_GREEN
	mov		r1, #5
	bl 		blink
	
	b 		reset

game_lost:
	mov		r0, #LED_RED
	mov		r1, #5
	bl 		blink
	
	mov		r0, #LED_RED
	mov		r1, #5
	bl 		blink

	mov		r0, #LED_RED
	mov		r1, #5
	bl 		blink
	
	b 		reset

; ----------------- Low-level I/O --------------------
outport_write:
	mov		r1, #OUTPORT_ADDRESS & 0xFF
	movt	r1, #(OUTPORT_ADDRESS >> 8) & 0xFF
	strb	r0, [r1, #0]
	mov		pc, lr

inport_read:
	mov		r1, #INPORT_ADDRESS & 0xFF
	movt	r1, #(INPORT_ADDRESS >> 8) & 0xFF
	ldrb	r0, [r1, #0]
	mov		pc, lr
; ----------------- LED control --------------------
; Blinks all the LED once in the r0 color and for r1 miliseconds
blink:
	push 	lr
	mov 	r2, r1
	mov 	r1, r0

	mov 	r0, #ALL_LEDS
	bl 		led

	mov 	r0, r2
	bl 		sleep
	
	mov 	r0, #ALL_LEDS
	bl 		clear
	
	mov 	r0, r2
	bl 		sleep

	pop pc

; r0 - máscara de ALL_LEDs a afetar (bit0=LED0, bit1=LED1, bit2=LED2, bit3=LED3)
clear:
    push 	lr
    mov 	r1, #LED_BLACK
    bl 		led
    pop 	pc


; led - Acende/apaga ALL_LEDs com persistência de estado
;   r0 - máscara de ALL_LEDs a afetar (bit0=LED0, bit1=LED1, bit2=LED2, bit3=LED3)
;   r1 - cor: 00=apagar, 01/10/11=cores 1/2/3
led:
	push	lr
	push	r4
	push	r5

	mov		r4, r0			; r4 = máscara
	mov		r5, r1			; r5 = cor

	ldr		r2, led_state_addr
	ldrb	r3, [r2]		; r3 = estado atual do porto

	; --- LED0 ---
	mov		r0, #0x01
	and		r0, r4, r0		; bit 0 da máscara
	beq		led_skip0
	
	mov		r0, #0xFC		; 1111 1100 — limpa bits 1:0
	and		r3, r3, r0
	mov		r0, #0x03
	and		r0, r5, r0		; cor & 0x03 → posição 0
	orr		r3, r3, r0

	led_skip0:
		; --- LED1 ---
		mov	r0, #0x02
		and	r0, r4, r0		; bit 1 da máscara
		beq	led_skip1
		
		mov	r0, #0xF3		; 1111 0011 — limpa bits 3:2
		and	r3, r3, r0
		lsl	r0, r5, #2		; cor << 2 → posição 2
		mov	r1, #0x0C		; bits 3:2
		and	r0, r0, r1
		orr	r3, r3, r0
	led_skip1:
		; --- LED2 ---
		mov	r0, #0x04
		and	r0, r4, r0		; bit 2 da máscara
		beq	led_skip2
		
		mov	r0, #0xCF		; 1100 1111 — limpa bits 5:4
		and	r3, r3, r0
		lsl	r0, r5, #4		; cor << 4 → posição 4
		mov	r1, #0x30		; bits 5:4
		and	r0, r0, r1
		orr	r3, r3, r0
	led_skip2:
		; --- LED3 ---
		mov	r0, #0x08
		and	r0, r4, r0		; bit 3 da máscara
		beq	led_skip3
		
		mov	r0, #0x3F		; 0011 1111 — limpa bits 7:6
		and	r3, r3, r0
		lsl	r0, r5, #6		; cor << 6 → posição 6
		mov	r1, #0xC0		; máscara bits 7:6
		and	r0, r0, r1
		orr	r3, r3, r0
	led_skip3:

		strb r3, [r2]	; guardar novo estado em led_state
		mov	r0, r3
		bl	outport_write	; aplicar ao porto de saída
		
	pop		r5
	pop		r4
	pop		lr
	mov		pc, lr

led_state_addr:
	.word	led_state

; ------------------- Button edge detection ---------------------
check_buttons:
    push 	lr

    bl  	inport_read             ; r0 = valor atual da entrada

    ; Isolar apenas os 4 bits dos botões (bits 3:0)
    mov 	r1, #0x0F
    and 	r0, r0, r1              ; r0 = estado atual dos 4 botões

    ; Carregar estado anterior
    ldr 	r2, addr_prev_buttons
    ldr 	r3, [r2]                ; r3 = estado anterior

    ; Guardar estado atual como novo "anterior"
    str 	r0, [r2]

    ; cliques = prev AND NOT(atual)  →  flancos de descida
    mvn 	r1, r0
    and 	r0, r3, r1

    ; Mascarar para garantir apenas bits 3:0
    mov 	r1, #0x0F
    and 	r0, r0, r1              ; r0 = máscara de cliques

    pop 	pc

addr_prev_buttons:
    .word 	prev_buttons

; -------------------- PRNG (XORShift) ---------------------------
init_random:
	ldr 	r1, addr_random_state
    str 	r0, [r1]

get_random:
	ldr 	r2, addr_random_state
    ldr 	r0, [r2]

	lsl 	r1, r0, #7
	eor 	r0, r0, r1      

	lsr 	r1, r0, #5
	eor 	r0, r0, r1   
	
	lsl 	r1, r0, #3
	eor 	r0, r0, r1   
	
	str 	r0, [r2]
	mov 	pc, lr

addr_random_state:
	.word	random_state

; ----------------- pTC timer     -------------------- 
ptc_init:
    mov     r1, #PTC_BASE & 0xFF
    movt    r1, #(PTC_BASE >> 8) & 0xFF

    mov     r0, #0x03           ; bit0=stop, bit1=int enable
    strb    r0, [r1, #PTC_TCR]  ; parar pTC com interrupções ativas

    mov     r0, #100
    strb    r0, [r1, #PTC_TMR]  ; match = 100 ticks (100ms @ 1kHz)

    mov     r0, #0
    strb    r0, [r1, #PTC_TIR]  ; limpar TIR

    mov     pc, lr


ptc_start:
    and     r0, r0, r0
    bzs     ptc_start_done

    ldr     r1, addr_sleep_count
    str     r0, [r1, #0]        ; sleep_count = r0

    mov     r1, #PTC_BASE & 0xFF
    movt    r1, #(PTC_BASE >> 8) & 0xFF

    mov     r0, #0x03           ; parar + int enable
    strb    r0, [r1, #PTC_TCR]

    mov     r0, #0
    strb    r0, [r1, #PTC_TIR]  ; limpar TIR antes de arrancar

    mov     r0, #0x02           ; arrancar com int enable (bit1=1, bit0=0)
    strb    r0, [r1, #PTC_TCR]

ptc_start_done:
    mov     pc, lr


; Retorna r0=1 se sleep terminou (sleep_count == 0), r0=0 se ainda a correr
ptc_done:
    ldr     r1, addr_sleep_count
    ldr     r0, [r1, #0]
    and     r0, r0, r0          ; seta flags
    bzs     ptc_done_yes        ; Z=1 → sleep_count == 0 → terminou

    mov     r0, #0              ; ainda a correr
    mov     pc, lr

ptc_done_yes:
    mov     r0, #1              ; terminou
    mov     pc, lr


ptc_isr:
    push    lr
    push    r0
    push    r1
    push    r2

    mov     r1, #PTC_BASE & 0xFF
    movt    r1, #(PTC_BASE >> 8) & 0xFF

    mov     r0, #0
    strb    r0, [r1, #PTC_TIR]  ; limpar TIR

    ldr     r2, addr_sleep_count
    ldr     r0, [r2, #0]
    and     r0, r0, r0
    bzs     ptc_isr_exit        ; já era 0, não decrementa

    sub     r0, r0, #1
    str     r0, [r2, #0]

    and     r0, r0, r0
    bzc     ptc_isr_exit        ; Z=0 → ainda > 0, continuar

    ; sleep_count chegou a 0: parar pTC
    mov     r0, #0x03           ; stop + int enable (mantém enable para próximo ptc_start)
    strb    r0, [r1, #PTC_TCR]

ptc_isr_exit:
    pop     r2
    pop     r1
    pop     r0
    pop     lr
    movs    pc, lr
    ldr     r1, addr_sleep_running
    ldr     r0, [r1, #0]
    and     r0, r0, r0
    bzs     ptc_done_yes 

    mov     r0, #0
    mov     pc, lr


sleep:
    push    lr
    bl      ptc_start

	sleep_loop:
		bl	ptc_done
		and	r0, r0, r0
		bzc	sleep_loop

    pop     pc


addr_sleep_count:
	.word 	sleep_count
addr_sleep_running:
	.word 	sleep_running

.data
Mole_test: 		.byte 	0b0001, 0b1000, 0b0010, 0b0100, 0b0110, 0b1010, 0b0111, 0b1011, 0b1101, 0b1111
led_state:		.word	0		; estado persistente dos 4 LEDs
prev_buttons:	.word 	0x0F    ; todos os botões começam soltos (bit=1 = solto)
random_state:	.word 	0
sleep_count:    .word   0
sleep_running:  .word   0
round:			.word  	0
	.stack
	.space	STACK_SIZE
stack_top:
