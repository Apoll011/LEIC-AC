    .equ  PTC_BASE,     0xFF
    .equ  PTC_TCR,      0b0000
    .equ  PTC_TMR,      0b0010
    .equ  PTC_TC,       0b0100
    .equ  PTC_TIR,      0b0110

    .data
sleep_count:    .word   0
sleep_running:  .word   0

;  ptc_init — Inicializa o pTC
    .text
ptc_init:
    mov      r1, #0
    movt     r1, #PTC_BASE

    mov      r0, #0x01 
    strb     r0, [r1, #PTC_TCR] ; Desativar Contagem

    mov     r0, #10
    strb    r0, [r1, #PTC_TMR]  ; Colocar 5 no TMR

    mov     r0, #0
    strb    r0, [r1, #PTC_TIR]  ; Limpar TIR

    mov     pc, lr


;  ptc_start — Arranca o timer.
ptc_start:
    and     r0, r0, r0
    bzs     ptc_start_done

    mov     r1, #sleep_count
    str     r0, [r1, #0]

    mov     r0, #1
    mov     r1, #sleep_running
    str     r0, [r1, #0]

    mov      r1, #0
    movt     r1, #PTC_BASE

    ;mov      r0, #0x01
    ;strb     r0, [r1, #PTC_TCR]

    mov     r0, #0
    strb    r0, [r1, #PTC_TIR]

    ; Arrancar (TCR=0)
    strb    r0, [r1, #PTC_TCR]

ptc_start_done:
    pop     pc


;  ptc_done — Verifica se o timer terminou.
ptc_done:
    mov     r1, #sleep_running
    ldr     r0, [r1, #0]
    and     r0, r0, r0
    bzs     ptc_done_yes 

    mov     r0, #0
    mov     pc, lr

ptc_done_yes:
    mov     r0, #1
    mov     pc, lr


; Dorme pelo tempo em r0
sleep:
    push    lr
    bl      ptc_start

sleep_loop:
    bl      ptc_done
    and     r0, r0, r0
    bzc     sleep_loop

    pop     pc

ptc_isr:
    push    lr
    push    r0
    push    r1
    push    r2

    mov     r1, #0
    movt    r1, #PTC_BASE
    
    mov     r0, #0
    strb    r0, [r1, #PTC_TIR] ; Limpa o TIR

    mov     r2, #sleep_count
    ldr     r0, [r2, #0]
    sub     r0, r0, #1
    str     r0, [r2, #0]

    ; 3. Se sleep_count == 0 - parar pTC e marcar como terminado
    and     r0, r0, r0
    bzc     ptc_isr_exit        ; ainda > 0, continuar

    mov      r1, #0
    movt     r1, #PTC_BASE

    mov      r0, #0x01
    strb     r0, [r1, #PTC_TCR]

    ; Marcar como terminado
    mov     r0, #0
    mov     r1, #sleep_running
    str     r0, [r1, #0]

ptc_isr_exit:
    pop     r2
    pop     r1
    pop     r0
    pop     lr
    movs    pc, lr
