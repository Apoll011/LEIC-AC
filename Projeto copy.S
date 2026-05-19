; Ficheiro:  Projeto.S
; Descricao: Deteta pressionar de botão e alterna LED bicolor (vermelho/apagado)
; Autor:     A54193 & A53107

    .equ    STACK_SIZE, 64

    .equ    INPORT_ADDRESS,  0xFF80
    .equ    OUTPORT_ADDRESS, 0xFFC0

    .equ    BUTTON1_MASK, 0x01      ; Botão 1 está no bit 0 da entrada

    .equ    LED0_MASK,  0x01        ; LED0 é o LED bicolor a usar
    .equ    LED_BLACK,  0x00
    .equ    LED_RED,    0x01

    .text
    b   program
    b   .           ; Reservado para ISR

program:
    ldr sp, stack_top_addr
    b   main

stack_top_addr:
    .word stack_top

main:
    ; Garantir que todos os LEDs começam apagados
    mov r0, #LED0_MASK
    bl  clear

main_loop:
    bl  check_button
    b   main_loop


; check_button - Deteta flanco descendente (soltar botão = clique)
;   Lê o botão atual, compara com estado anterior.
;   clique = prev AND NOT atual  (flanco de descida)
check_button:
    push lr
    push r4

    bl  inport_read         ; r0 = valor lido na entrada

    ; Isolar bit do botão 1
    mov r1, #BUTTON1_MASK
    and r4, r0, r1          ; r4 = estado atual do botão

    ; Carregar prev_button
    ldr r1, addr_prev_button
    ldr r2, [r1]            ; r2 = estado anterior

    ; Guardar estado atual em prev_button
    str r4, [r1]

    ; clique = estado_anterior AND NOT(estado_atual)
    mvn r0, r4
    and r0, r0, r2

    ; Mascarar para garantir apenas o bit do botão 1
    mov r1, #BUTTON1_MASK
    and r0, r0, r1

    ; Houve clique?
    mov r1, #0
    cmp r0, r1
    beq check_done

    ; Sim — alternar LED
    bl  toggle_led

check_done:
    pop r4
    pop pc

addr_prev_button:
    .word prev_button


; toggle_led - Alterna LED0 entre vermelho e apagado
toggle_led:
    push lr

    ldr r1, addr_led_logic
    ldrb r0, [r1]           ; r0 = estado lógico atual (0 ou 1)

    mov r2, #0
    cmp r0, r2
    beq toggle_on           ; estava apagado → acender

toggle_off:
    mov r0, #0
    strb r0, [r1]           ; guardar novo estado lógico

    mov r0, #LED0_MASK
    bl  clear               ; apagar LED no porto

    pop pc

toggle_on:
    mov r0, #1
    strb r0, [r1]           ; guardar novo estado lógico

    mov r0, #LED0_MASK
    mov r1, #LED_RED
    bl  led                 ; acender LED a vermelho

    pop pc

addr_led_logic:
    .word led_logic



inport_read:
    mov  r1, #INPORT_ADDRESS & 0xFF
    movt r1, #(INPORT_ADDRESS >> 8) & 0xFF
    ldrb r0, [r1, #0]
    mov  pc, lr


; clear - Apaga os LEDs indicados pela máscara em r0
clear:
    push lr
    mov r1, #LED_BLACK
    bl  led
    pop lr
    mov pc, lr


; led - Atualiza LEDs com persistência de estado
;   r0 = máscara de LEDs (bit0=LED0 … bit3=LED3)
;   r1 = cor (00=apagar, 01=vermelho, 10=verde, 11=amarelo)
led:
    push lr
    push r4
    push r5

    mov r4, r0
    mov r5, r1

    ldr r2, led_state_addr
    ldrb r3, [r2]

    ; --- LED0 ---
    mov r0, #0x01
    and r0, r4, r0
    beq led_skip0
    mov r0, #0xFC
    and r3, r3, r0
    mov r0, #0x03
    and r0, r5, r0
    orr r3, r3, r0
led_skip0:

    strb r3, [r2]
    mov  r0, r3
    bl   outport_write

    pop r5
    pop r4
    pop lr
    mov pc, lr

led_state_addr:
    .word led_state


outport_write:
    mov  r1, #OUTPORT_ADDRESS & 0xFF
    movt r1, #(OUTPORT_ADDRESS >> 8) & 0xFF
    strb r0, [r1, #0]
    mov  pc, lr


    .data

led_state:
    .word 0         ; Estado persistente dos LEDs no porto de saída

led_logic:
    .word 0         ; Estado lógico do LED0 (0=apagado, 1=aceso)

prev_button:
    .word 1         ; Estado anterior do botão (1 = não pressionado)

    .stack
    .space STACK_SIZE
stack_top:
