; =============================================================================
; FICHEIRO:    toupeira.s
; DESCRIÇÃO:   Implementação do Jogo "Caça à Toupeira" para o processador P16.
;              Otimizado para compilação robusta no assembler p16as.exe:
;              - Uso exclusivo de apontadores PC-relativos (LDR) de curto alcance
;                com as tabelas/variáveis (literal pools) locais em .text.
;              - Zero operações de bits (&, >>) sobre etiquetas em instruções MOV.
;              - Compatibilidade total com teste_botao.s e teste_led_bicolor.s.
; AUTOR:       Antigravity (AC 2025/2026)
; =============================================================================

; -----------------------------------------------------------------------------
; Definição de Constantes de Hardware
; -----------------------------------------------------------------------------
.equ IN_PORT,   0xFF80          ; Porto paralelo de entrada
.equ OUT_PORT,  0xFFC0          ; Porto paralelo de saída

; Definição de Endereços dos Registos do pTC (A1 e A2 do CPU -> A0 e A1 do pTC)
.equ PTC_TCR,   0xFF00          ; Timer Control Register
.equ PTC_TMR,   0xFF02          ; Timer Match Register
.equ PTC_TC,    0xFF04          ; Timer Counter
.equ PTC_TIR,   0xFF06          ; Timer Interrupt Register

; Configurações da Pilha
.equ STACK_SIZE, 64

; Máscaras dos Botões (Ativos a Baixo: 1 = solto, 0 = pressionado)
.equ BUTTON1_MASK, 0x01         ; Botão 1 -> Bit 0 (HIT_HOLE1)
.equ BUTTON2_MASK, 0x02         ; Botão 2 -> Bit 1 (HIT_HOLE2)
.equ BUTTON3_MASK, 0x04         ; Botão 3 -> Bit 2 (HIT_HOLE3)
.equ BUTTON4_MASK, 0x08         ; Botão 4 -> Bit 3 (HIT_HOLE4)
.equ BUTTONS_MASK, 0x0F         ; Máscara dos 4 botões

; Cores e Estados dos LEDs Bicolores (2 bits por LED)
.equ LED_OFF,    0x00           ; Todos os LEDs desligados
.equ ALL_YELLOW, 0xFF           ; Todos os LEDs a laranja/amarelo (início)
.equ ALL_GREEN,  0xAA           ; Todos os LEDs a verde
.equ ALL_RED,    0x55           ; Todos os LEDs a vermelho

; -----------------------------------------------------------------------------
; Secção de Código (.text) e Tabela de Vetores de Interrupção
; -----------------------------------------------------------------------------
.text

    b program                   ; Endereço 0x0000: Salto para o programa principal
    b interrupt_handler         ; Endereço 0x0002: Salto para a ISR (Vetor de Interrupção)

; -----------------------------------------------------------------------------
; Programa Principal
; -----------------------------------------------------------------------------
program:

    ; 1. Inicializar o Stack Pointer de forma PC-relativa curta
    ldr sp, stack_top_addr
    b main_init

stack_top_addr:
    .word stack_top             ; Apontador local para o topo do stack (RAM)

main_init:

    ; 2. Inicializar o pTC com o tempo base (100 ms)
    bl ptc_init

    ; 3. Ativar as interrupções globais no CPU (limpar bit I, que é o bit 4 do CPSR)
    MRS r0, CPSR
    mov r1, #0x10               ; Máscara para o bit 4 (I)
    orr r0, r0, r1              ; Limpa o bit 4 (I = 0 -> Interrupções ativas)
    MSR CPSR, r0

state_init:

    ; Estado inicial: todos os LEDs a laranja/amarelo (ALL_YELLOW)
    mov r0, #ALL_YELLOW
    bl escrever_saida

esperar_inicio:

    ; Espera que o botão 1 (HIT_HOLE1) seja clicado para iniciar o jogo
    mov r0, #BUTTON1_MASK
    bl esperar_clique

    ; Garante que o jogador solta o botão antes de iniciar a primeira ronda
    bl esperar_largar_botoes

    ; Inicializar a ronda atual a zero (Ronda 1)
    mov r0, #0
    ldr r1, addr_current_round_init
    str r0, [r1]
    b state_round_start

addr_current_round_init:
    .word current_round         ; Apontador local para current_round (RAM)

state_round_start:

    ; 1. Parar o timer pTC temporariamente enquanto configuramos a nova ronda
    bl ptc_stop

    ; 2. Ler o nível de dificuldade do DIP-switch (bits 5 a 7 de IN_PORT)
    bl ler_entrada
    mov r1, #0xE0               ; Máscara para bits 5..7
    and r0, r0, r1
    lsr r0, r0, #5              ; r0 = nível (0 a 7)

    ; 3. Obter a duração da ronda (em ticks) da tabela de nível
    lsl r0, r0, #1              ; r0 = nível * 2 (offset word)
    ldr r1, addr_level_ticks_table_rs
    ldr r2, [r1, r0]            ; r2 = número de ticks da ronda

    ; Inicializar o countdown_timer na RAM
    ldr r1, addr_countdown_timer_rs
    str r2, [r1]

    ; 4. Carregar o padrão de toupeiras correspondente à ronda atual (0 a 9)
    ldr r0, addr_current_round_rs
    ldr r0, [r0]                ; r0 = índice da ronda atual (0..9)
    lsl r0, r0, #1              ; r0 = ronda * 2 (offset word)
    ldr r1, addr_moles_round_table_rs
    ldr r2, [r1, r0]            ; r2 = máscara de toupeiras verdes desta ronda

    ; Inicializar as variáveis de controlo de toupeiras
    ldr r1, addr_current_mole_mask_rs
    str r2, [r1]                ; Guarda o padrão ativo da ronda
    
    mov r3, #0
    ldr r1, addr_hit_mole_mask_rs
    str r3, [r1]                ; Zera as toupeiras atingidas (nenhuma atingida)

    ; 5. Escrever a máscara inicial nos LEDs (toupeiras verdes visíveis nos buracos ativos)
    mov r0, r2
    bl escrever_saida

    ; 6. Limpar qualquer interrupção pendente e arrancar o timer pTC
    bl ptc_clear_int
    bl ptc_start
    b state_round_play

; Pointers locais para state_round_start (dentro do alcance de 7 bits)
addr_level_ticks_table_rs:  .word level_ticks_table
addr_countdown_timer_rs:    .word countdown_timer
addr_current_round_rs:      .word current_round
addr_moles_round_table_rs:  .word moles_round_table
addr_current_mole_mask_rs:  .word current_mole_mask
addr_hit_mole_mask_rs:      .word hit_mole_mask

state_round_play:

    ; 1. Verificar se o tempo da ronda expirou
    ldr r0, addr_countdown_timer_play
    ldr r0, [r0]
    mov r1, #0
    cmp r0, r1
    beq game_over_lost          ; Tempo expirou! Derrota por tempo limite.

    ; 2. Verificar se ocorreram cliques nos botões nesta iteração
    bl check_buttons            ; r0 = bits dos botões recém-clicados
    mov r6, r0                  ; r6 = botões clicados

    ; Se não houve cliques, continua à espera no ciclo de jogo
    mov r1, #0
    cmp r6, r1
    beq state_round_play
    b check_btn1

addr_countdown_timer_play:  .word countdown_timer

check_btn1:
    mov r1, #BUTTON1_MASK
    and r0, r6, r1
    mov r1, #0
    cmp r0, r1
    beq check_btn2              ; Botão 1 não foi premido

    ; Botão 1 premido: Existe toupeira verde no Buraco 1? (LED 1 Verde -> Bit 1)
    ldr r2, addr_current_mole_mask_play
    ldr r2, [r2]
    mov r1, #0x02               ; Máscara de LED 1 Verde
    and r2, r2, r1
    mov r1, #0
    cmp r2, r1
    beq check_btn2              ; Sem toupeira no buraco 1

    ; Há toupeira! Regista batida na hit_mole_mask (ativa bit 1)
    ldr r3, addr_hit_mole_mask_play
    ldr r4, [r3]
    mov r1, #0x02
    orr r4, r4, r1
    str r4, [r3]

check_btn2:
    mov r1, #BUTTON2_MASK
    and r0, r6, r1
    mov r1, #0
    cmp r0, r1
    beq check_btn3

    ; Botão 2 premido: Existe toupeira verde no Buraco 2? (LED 2 Verde -> Bit 3)
    ldr r2, addr_current_mole_mask_play
    ldr r2, [r2]
    mov r1, #0x08               ; Máscara de LED 2 Verde
    and r2, r2, r1
    mov r1, #0
    cmp r2, r1
    beq check_btn3

    ; Regista batida (ativa bit 3 na hit_mole_mask)
    ldr r3, addr_hit_mole_mask_play
    ldr r4, [r3]
    mov r1, #0x08
    orr r4, r4, r1
    str r4, [r3]

    b check_btn3

; Pointers partilhados de curto alcance para o loop de jogo
addr_current_mole_mask_play: .word current_mole_mask
addr_hit_mole_mask_play:     .word hit_mole_mask

check_btn3:
    mov r1, #BUTTON3_MASK
    and r0, r6, r1
    mov r1, #0
    cmp r0, r1
    beq check_btn4

    ; Botão 3 premido: Existe toupeira verde no Buraco 3? (LED 3 Verde -> Bit 5)
    ldr r2, addr_current_mole_mask_play2
    ldr r2, [r2]
    mov r1, #0x20               ; Máscara de LED 3 Verde
    and r2, r2, r1
    mov r1, #0
    cmp r2, r1
    beq check_btn4

    ; Regista batida (ativa bit 5 na hit_mole_mask)
    ldr r3, addr_hit_mole_mask_play2
    ldr r4, [r3]
    mov r1, #0x20
    orr r4, r4, r1
    str r4, [r3]

check_btn4:
    mov r1, #BUTTON4_MASK
    and r0, r6, r1
    mov r1, #0
    cmp r0, r1
    beq atualizar_leds

    ; Botão 4 premido: Existe toupeira verde no Buraco 4? (LED 4 Verde -> Bit 7)
    ldr r2, addr_current_mole_mask_play2
    ldr r2, [r2]
    mov r1, #0x80               ; Máscara de LED 4 Verde
    and r2, r2, r1
    mov r1, #0
    cmp r2, r1
    beq atualizar_leds

    ; Regista batida (ativa bit 7 na hit_mole_mask)
    ldr r3, addr_hit_mole_mask_play2
    ldr r4, [r3]
    mov r1, #0x80
    orr r4, r4, r1
    str r4, [r3]

atualizar_leds:

    ; Calcula o valor para os LEDs dinamicamente com base nas atingidas:
    ; output = (current_mole_mask & ~hit_mole_mask) | (hit_mole_mask >> 1)
    ldr r2, addr_current_mole_mask_play2
    ldr r2, [r2]
    ldr r3, addr_hit_mole_mask_play2
    ldr r3, [r3]

    mvn r4, r3                  ; r4 = ~hit_mole_mask
    and r4, r2, r4              ; r4 = toupeiras que ainda estão a verde

    lsr r5, r3, #1              ; r5 = hit_mole_mask >> 1 (as atingidas passam a vermelho)
    orr r0, r4, r5              ; r0 = combinação das cores dos LEDs
    bl escrever_saida

    ; Verificar se todas as toupeiras ativas nesta ronda foram atingidas
    ; Condição de sucesso: hit_mole_mask == current_mole_mask
    cmp r3, r2
    bne state_round_play        ; Se ainda faltam toupeiras, continua a jogar
    b round_success

; Pointers partilhados de curto alcance para a parte final do play loop
addr_current_mole_mask_play2: .word current_mole_mask
addr_hit_mole_mask_play2:     .word hit_mole_mask

round_success:

    ; Ronda concluída com sucesso!
    bl ptc_stop
    bl delay_250ms
    bl delay_250ms              ; Pequeno atraso antes de avançar para a próxima ronda
    ; 1. Apagar os quatro LEDs (ausência de toupeiras)
    mov r0, #LED_OFF
    bl escrever_saida

    ; 2. Período de espera fixa de 0.5 segundos (250ms * 2 de espera activa)
    bl delay_250ms
    bl delay_250ms

    ; 3. Verificar se o jogador completou a ronda 10 (índice 9)
    ldr r1, addr_current_round_succ
    ldr r0, [r1]
    mov r2, #9                  ; Index 9 = Ronda 10
    cmp r0, r2
    beq game_over_won           ; Venceu o jogo!

    ; Caso contrário, avança para a ronda seguinte
    add r0, r0, #1
    str r0, [r1]
    b state_round_start

addr_current_round_succ:
    .word current_round

game_over_lost:

    ; Perdeu o jogo: Para o timer e pisca os 4 LEDs bicolor 3 vezes a vermelho
    bl ptc_stop
    
    mov r0, #ALL_RED
    bl flash_leds

    b state_init

game_over_won:

    ; Venceu o jogo: Para o timer e pisca os 4 LEDs bicolor 3 vezes a verde
    bl ptc_stop
    
    mov r0, #ALL_GREEN
    bl flash_leds

    b state_init

; -----------------------------------------------------------------------------
; Rotinas Auxiliares / Subrotinas
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; flash_leds
;
; Entrada:
;   r0 = máscara de cores a piscar (ALL_RED ou ALL_GREEN)
; Efeitos: Pisca os 4 LEDs bicolor 3 vezes, com período de oscilação de 0.5s.
; -----------------------------------------------------------------------------
flash_leds:
    push lr
    push r4
    push r5

    mov r4, r0                  ; r4 = cor do pisca
    mov r5, #3                  ; 3 iterações de pisca

flash_loop:
    ; Liga LEDs com a cor escolhida
    mov r0, r4
    bl escrever_saida
    bl delay_250ms              ; 250 ms aceso

    ; Apaga LEDs
    mov r0, #LED_OFF
    bl escrever_saida
    bl delay_250ms              ; 250 ms apagado

    sub r5, r5, #1
    bne flash_loop

    pop r5
    pop r4
    pop pc

; -----------------------------------------------------------------------------
; delay_250ms (Inspirada no delay de teste_led_bicolor.s)
;
; Pequeno atraso ativo de aproximadamente 250ms (baseado em MCLK = 50 kHz).
; -----------------------------------------------------------------------------
delay_250ms:
    push r4
    push r5
    mov r4, #0x28               ; Ajustado para o CPU SDP16 a 50 kHz
delay_250_ext:
    mov r5, #0x28
delay_250_int:
    sub r5, r5, #1
    bne delay_250_int
    sub r4, r4, #1
    bne delay_250_ext
    pop r5
    pop r4
    mov pc, lr

; -----------------------------------------------------------------------------
; ptc_init
;
; Configura o pTC para tick de 100ms assumindo CLK de 1 kHz.
; TMR = 99 (0x63), TCR = 1 (timer parado/limpo)
; -----------------------------------------------------------------------------
ptc_init:
    push lr
    
    mov r0, #99                 ; match value = 99
    bl ptc_set_tmr
    
    bl ptc_stop                 ; garante pTC desligado no arranque
    
    pop pc

; -----------------------------------------------------------------------------
; ptc_start
;
; Arranca o temporizador síncrono pTC (escreve 0 no TCR).
; -----------------------------------------------------------------------------
ptc_start:
    mov r1, #PTC_TCR & 0xFF
    movt r1, #(PTC_TCR >> 8) & 0xFF
    mov r0, #0
    strb r0, [r1]
    mov pc, lr

; -----------------------------------------------------------------------------
; ptc_stop
;
; Pára e limpa o pTC (escreve 1 no TCR).
; -----------------------------------------------------------------------------
ptc_stop:
    mov r1, #PTC_TCR & 0xFF
    movt r1, #(PTC_TCR >> 8) & 0xFF
    mov r0, #1
    strb r0, [r1]
    mov pc, lr

; -----------------------------------------------------------------------------
; ptc_set_tmr
;
; Define o registo do Match Register (TMR) do pTC com o valor em r0.
; -----------------------------------------------------------------------------
ptc_set_tmr:
    mov r1, #PTC_TMR & 0xFF
    movt r1, #(PTC_TMR >> 8) & 0xFF
    strb r0, [r1]
    mov pc, lr

; -----------------------------------------------------------------------------
; ptc_clear_int
;
; Limpa a linha de interrupção ativa no pTC escrevendo no TIR.
; -----------------------------------------------------------------------------
ptc_clear_int:
    mov r1, #PTC_TIR & 0xFF
    movt r1, #(PTC_TIR >> 8) & 0xFF
    mov r0, #1
    strb r0, [r1]
    mov pc, lr

; -----------------------------------------------------------------------------
; esperar_clique (Aproveita a detecção de clique de teste_botao.s)
;
; Entrada:
;   r0 = máscara do botão esperado
; Espera até haver transição descendente 1->0 no botão.
; -----------------------------------------------------------------------------
esperar_clique:
    push lr
    push r4
    push r5
    mov r5, r0
esperar_clique_loop:
    bl check_buttons
    and r0, r0, r5
    mov r1, #0
    cmp r0, r1
    beq esperar_clique_loop
    pop r5
    pop r4
    pop pc

; -----------------------------------------------------------------------------
; check_buttons (Implementa a lógica central de teste_botao.s)
;
; Saída:
;   r0 = bits dos botões onde ocorreu clique (transição 1->0)
; -----------------------------------------------------------------------------
check_buttons:
    push lr
    push r4

    bl ler_entrada
    mov r1, #BUTTONS_MASK
    and r4, r0, r1              ; r4 = estado atual dos 4 botões

    ldr r1, addr_prev_buttons_cb
    ldr r2, [r1]                ; r2 = estado anterior

    str r4, [r1]                ; guarda o estado atual para o próximo ciclo

    mvn r0, r4
    and r0, r0, r2              ; clique = estado_anterior AND NOT estado_atual

    mov r1, #BUTTONS_MASK
    and r0, r0, r1

    pop r4
    pop pc

addr_prev_buttons_cb:
    .word prev_buttons

; -----------------------------------------------------------------------------
; esperar_largar_botoes
;
; Espera até os 4 botões estarem soltos (ativo a alto -> bits a 1).
; -----------------------------------------------------------------------------
esperar_largar_botoes:
    push lr
esperar_largar_loop:
    bl ler_entrada
    mov r1, #BUTTONS_MASK
    and r0, r0, r1
    cmp r0, r1
    bne esperar_largar_loop

    ; Atualiza estado anterior para botões soltos (prev_buttons = BUTTONS_MASK)
    ldr r1, addr_prev_buttons_el
    mov r0, #BUTTONS_MASK
    str r0, [r1]
    pop pc

addr_prev_buttons_el:
    .word prev_buttons

; -----------------------------------------------------------------------------
; ler_entrada (Similar a read_input de teste_botao.s)
; escrever_saida (Similar a outport_write de lab03.s / escolher_led de teste_led_bicolor.s)
; -----------------------------------------------------------------------------
ler_entrada:
    mov r1, #IN_PORT & 0xFF
    movt r1, #(IN_PORT >> 8) & 0xFF
    ldrb r0, [r1]
    mov pc, lr

escrever_saida:
    mov r1, #OUT_PORT & 0xFF
    movt r1, #(OUT_PORT >> 8) & 0xFF
    strb r0, [r1]
    mov pc, lr

; -----------------------------------------------------------------------------
; Rotina de Serviço de Interrupção (ISR)
;
; Chamada a cada tick do pTC (100 ms).
; Decrementa o countdown_timer na RAM caso seja maior que zero.
; -----------------------------------------------------------------------------
interrupt_handler:
    push lr                     ; Guarda o endereço de retorno da interrupção
    push r0
    push r1
    push r2

    ; 1. Reconhecer/limpar a interrupção no hardware do pTC
    mov r1, #PTC_TIR & 0xFF
    movt r1, #(PTC_TIR >> 8) & 0xFF
    mov r0, #1
    strb r0, [r1]

    ; 2. Decrementar o countdown_timer global caso seja > 0
    ldr r1, addr_countdown_timer_isr
    ldr r0, [r1]
    mov r2, #0
    cmp r0, r2
    beq int_done
    sub r0, r0, #1
    str r0, [r1]

int_done:
    ; 3. Restaurar contexto e retornar com MOVS PC, LR (restaura CPSR <- SPSR)
    pop r2
    pop r1
    pop r0
    pop lr
    movs pc, lr

addr_countdown_timer_isr:
    .word countdown_timer

; -----------------------------------------------------------------------------
; Secção de Dados Globais (.data)
; -----------------------------------------------------------------------------
.data

prev_buttons:
    .word BUTTONS_MASK          ; Guarda o estado anterior dos botões

current_round:
    .word 0                     ; Ronda atual (índice 0 a 9)

countdown_timer:
    .word 0                     ; Contador decrescente de ticks na ronda corrente

current_mole_mask:
    .word 0                     ; Máscara de toupeiras ativas na ronda

hit_mole_mask:
    .word 0                     ; Máscara de toupeiras atingidas na ronda

; Tabela de Ticks de Dificuldade por Nível (DIP-switch 0..7)
level_ticks_table:
    .word 100                   ; Nível 0: 10 s (100 ticks)
    .word 90                    ; Nível 1: 9 s  (90 ticks)
    .word 80                    ; Nível 2: 8 s  (80 ticks)
    .word 70                    ; Nível 3: 7 s  (70 ticks)
    .word 60                    ; Nível 4: 6 s  (60 ticks)
    .word 50                    ; Nível 5: 5 s  (50 ticks)
    .word 30                    ; Nível 6: 3 s  (30 ticks)
    .word 15                    ; Nível 7: 1.5 s(15 ticks)

; Tabela de Padrões das Toupeiras (Buracos verdes ativos) para cada uma das 10 Rondas
moles_round_table:
    .word 0x02                  ; Ronda 1:  Hole 1 Green (bit 1)
    .word 0x20                  ; Ronda 2:  Hole 3 Green (bit 5)
    .word 0x08                  ; Ronda 3:  Hole 2 Green (bit 3)
    .word 0x80                  ; Ronda 4:  Hole 4 Green (bit 7)
    .word 0x0A                  ; Ronda 5:  Holes 1 & 2 Green (bits 1, 3)
    .word 0xA0                  ; Ronda 6:  Holes 3 & 4 Green (bits 5, 7)
    .word 0x22                  ; Ronda 7:  Holes 1 & 3 Green (bits 1, 5)
    .word 0x88                  ; Ronda 8:  Holes 2 & 4 Green (bits 3, 7)
    .word 0x2A                  ; Ronda 9:  Holes 1, 2 & 3 Green (bits 1, 3, 5)
    .word 0xA8                  ; Ronda 10: Holes 2, 3 & 4 Green (bits 3, 5, 7)

; -----------------------------------------------------------------------------
; Secção do Segmento de Pilha (.stack)
; -----------------------------------------------------------------------------
.stack
    .space STACK_SIZE
stack_top:
