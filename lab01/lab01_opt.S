; =========================================================
; Trabalho 1 - Arquitetura de Computadores
; =========================================================

; =========================================================
; CONSTANTES
; =========================================================
.equ VAL_MIN, 5                 ; define a constante VAL_MIN com valor 5

; =========================================================
; DADOS
; =========================================================
.data                           ; início da secção de dados

array_k1:    .byte 205, 154, 102, 51, 0   ; array de coeficientes k da 1.ª sequência, terminado em 0
array_s1:    .byte 8, 8, 8, 8, 0          ; array de expoentes s da 1.ª sequência, terminado em 0
array_vals1: .space 12                    ; reserva 12 bytes para guardar 6 valores de 16 bits

array_k2:    .byte 35, 38, 42, 45, 0      ; array de coeficientes k da 2.ª sequência
array_s2:    .byte 5, 5, 5, 5, 0          ; array de expoentes s da 2.ª sequência
array_vals2: .space 12                    ; reserva 12 bytes para os valores da 2.ª sequência

array_k3:    .byte 205, 154, 0, 45, 35, 0 ; array de coeficientes k da 3.ª sequência
array_s3:    .byte 8, 8, 0, 5, 5, 0       ; array de expoentes s da 3.ª sequência
array_vals3: .space 14                    ; reserva 14 bytes para 7 valores de 16 bits

n1:          .word 0                      ; variável para guardar o número de elementos da 1.ª sequência
n2:          .word 0                      ; variável para guardar o número de elementos da 2.ª sequência
n3:          .word 0                      ; variável para guardar o número de elementos da 3.ª sequência

; =========================================================
; PILHA
; =========================================================
.stack                          ; início da secção da pilha
    .space 64                   ; reserva 64 bytes para a pilha
stack_top:                      ; etiqueta que marca o topo da pilha

; =========================================================
; CÓDIGO
; =========================================================
.text                           ; início da secção de código
    b start                     ; salta para o ponto de arranque do programa
    b .                         ; vetor reservado (fica em loop infinito)

start:
    ldr sp, stack_top_addr      ; inicializa o stack pointer com o endereço de stack_top
    b main                      ; salta para a rotina main

stack_top_addr: .word stack_top ; palavra com o endereço de stack_top para carregar em SP

; =========================================================
; clamp_value
; r0 = val, r1 = min, r2 = max
; devolve r0 limitado a [min, max]
; =========================================================
clamp_value:
    cmp r0, r1                  ; compara val com min
    blo clamp_min               ; se val < min salta para clamp_min

    cmp r2, r0                  ; compara max com val
    blo clamp_max               ; se max < val, então val é demasiado grande e vai para clamp_max

    mov pc, lr                  ; caso contrário devolve val sem alterações

clamp_min:
    mov r0, r1                  ; coloca min em r0
    mov pc, lr                  ; retorna da rotina

clamp_max:
    mov r0, r2                  ; coloca max em r0
    mov pc, lr                  ; retorna da rotina

; =========================================================
; umul
; Baseado no código do lab
; Entrada: r0 = a, r1 = b
; Saída:   r1:r0 = a * b
; =========================================================
umul:
    push lr                     ; guarda o endereço de retorno
    push r4                     ; guarda r4 porque vai ser usado e deve ser preservado

    mov r4, #0                  ; inicializa r4 a 0, vai guardar a parte alta do produto
    mov r2, #0                  ; inicializa r2 a 0, vai guardar a parte baixa do produto

if:
    mov r3, #0                  ; coloca 0 em r3 para usar na comparação
    cmp r0, r3                  ; compara a com 0
    beq while_end               ; se a == 0, o produto é 0 e termina
    b while                     ; caso contrário entra no ciclo

while:
    mov r3, #0                  ; coloca novamente 0 em r3
    cmp r3, r1                  ; compara 0 com b
    bhs while_end               ; se 0 >= b, ou seja, b == 0, termina

    add r2, r2, r0              ; soma a à parte baixa do acumulador
    adc r4, r4, r3              ; soma o carry à parte alta (r3 vale 0, logo só propaga carry)
    sub r1, r1, #1              ; decrementa b
    b while                     ; repete o ciclo

while_end:
    mov r0, r2                  ; coloca a parte baixa do produto em r0
    mov r1, r4                  ; coloca a parte alta do produto em r1
    pop r4                      ; restaura o valor original de r4
    pop pc                      ; retorna da rotina restaurando o PC

; =========================================================
; scale_value
; r0 = v, r1 = k, r2 = s
; devolve max( floor((v*k + 2^(s-1))/2^s), VAL_MIN )
; =========================================================
scale_value:
    push lr                     ; guarda o endereço de retorno
    push r4                     ; guarda r4
    push r5                     ; guarda r5
    push r6                     ; guarda r6
    push r7                     ; guarda r7

    mov r4, r2                  ; guarda s em r4 para o usar mais à frente

    bl umul                     ; chama a multiplicação: calcula v * k e devolve em r1:r0

    mov r5, r1                  ; guarda a parte alta do produto em r5
    mov r6, r0                  ; guarda a parte baixa do produto em r6
    mov r7, #1                  ; coloca 1 em r7, usado em vários cálculos
    mov r3, #0                  ; coloca 0 em r3, usado em comparações

    cmp r4, r3                  ; compara s com 0
    beq shift_part              ; se s == 0, não faz arredondamento e vai diretamente ao shift

    mov r2, r4                  ; copia s para r2
    sub r2, r2, r7              ; calcula s - 1
    mov r1, r7                  ; inicializa a potência com 1

pow_loop:
    cmp r2, r3                  ; verifica se o contador chegou a 0
    beq pow_end                 ; se sim, termina o cálculo da potência
    lsl r1, r1, #1              ; multiplica a potência por 2
    sub r2, r2, r7              ; decrementa o contador
    b pow_loop                  ; repete o ciclo

pow_end:
    add r6, r6, r1              ; soma 2^(s-1) à parte baixa do produto para arredondamento
    bcc pow_no_carry            ; se não houver carry, continua
    add r5, r5, r7              ; se houver carry, incrementa a parte alta

pow_no_carry:

shift_part:
    mov r2, r4                  ; coloca s em r2 para servir de contador do shift

shift_loop:
    cmp r2, r3                  ; verifica se já fez todos os shifts
    beq clamp_part              ; se sim, vai aplicar o clamp

    and r1, r5, r7              ; isola o bit menos significativo da parte alta
    lsr r5, r5, #1              ; faz shift right da parte alta
    lsr r6, r6, #1              ; faz shift right da parte baixa

    cmp r1, r3                  ; verifica se o bit retirado da parte alta era 0
    beq shift_next              ; se era 0, não é preciso alterar a parte baixa

    mov r1, #0x80               ; carrega 0x80
    lsl r1, r1, #8              ; transforma em 0x8000
    orr r6, r6, r1              ; coloca esse bit no topo da parte baixa

shift_next:
    sub r2, r2, r7              ; decrementa o contador de shifts
    b shift_loop                ; repete até fazer s shifts

clamp_part:
    mov r0, r6                  ; coloca o valor final em r0
    mov r2, r0                  ; coloca esse mesmo valor em r2 para servir de máximo
    mov r1, #VAL_MIN            ; coloca VAL_MIN em r1 para servir de mínimo
    bl clamp_value              ; garante que o valor não desce abaixo de VAL_MIN

    pop r7                      ; restaura r7
    pop r6                      ; restaura r6
    pop r5                      ; restaura r5
    pop r4                      ; restaura r4
    pop pc                      ; retorna da rotina

; =========================================================
; build_sequence
; r0 = v_init, r1 = v[], r2 = k[], r3 = s[]
; devolve r0 = número de elementos escritos
; =========================================================
build_sequence:
    push lr                     ; guarda o endereço de retorno
    push r4                     ; guarda r4
    push r5                     ; guarda r5
    push r6                     ; guarda r6
    push r7                     ; guarda r7
    push r2                     ; guarda a base do array k[] na pilha

    mov r4, #0                  ; i = 0
    mov r5, r0                  ; guarda o valor atual da sequência
    mov r6, r1                  ; guarda a base do array v[]
    mov r7, r3                  ; guarda a base do array s[]

    str r5, [r6]                ; escreve v[0] = v_init

build_loop:
    add r0, r7, r4              ; calcula o endereço de s[i]
    ldrb r3, [r0]               ; lê s[i] em r3

    mov r1, #0                  ; coloca 0 em r1
    cmp r3, r1                  ; verifica se s[i] == 0
    beq build_end               ; se sim, termina a construção da sequência

    mov r0, sp                  ; coloca o valor atual de SP em r0
    ldr r0, [r0]                ; lê da pilha a base do array k[]
    add r0, r0, r4              ; calcula o endereço de k[i]
    ldrb r1, [r0]               ; lê k[i] em r1

    mov r2, r3                  ; coloca s[i] em r2
    mov r0, r5                  ; coloca v[i] em r0
    bl scale_value              ; calcula o próximo valor da sequência

    mov r5, r0                  ; atualiza o valor atual com o resultado devolvido
    add r4, r4, #1              ; incrementa i

    mov r0, r4                  ; coloca i em r0
    lsl r0, r0, #1              ; multiplica i por 2 para obter offset em bytes
    add r0, r6, r0              ; calcula o endereço de v[i]
    str r5, [r0]                ; escreve o novo valor em v[i]

    b build_loop                ; repete o ciclo

build_end:
    add r0, r4, #1              ; devolve o número de elementos escritos = i + 1

    pop r2                      ; restaura o valor guardado de r2
    pop r7                      ; restaura r7
    pop r6                      ; restaura r6
    pop r5                      ; restaura r5
    pop r4                      ; restaura r4
    pop pc                      ; retorna da rotina

; =========================================================
; main
; =========================================================
main:
    push lr                     ; guarda o endereço de retorno
    push r4                     ; guarda r4
    push r5                     ; guarda r5
    push r6                     ; guarda r6

    mov r0, #100                ; coloca 100 como valor inicial da 1.ª sequência
    ldr r1, addr_vals1          ; carrega o endereço do array de resultados da 1.ª sequência
    ldr r2, addr_k1             ; carrega o endereço do array k1
    ldr r3, addr_s1             ; carrega o endereço do array s1
    bl build_sequence           ; constrói a 1.ª sequência
    mov r4, r0                  ; guarda em r4 o número de elementos escritos

    mov r0, #10                 ; coloca 10 como valor inicial da 2.ª sequência
    ldr r1, addr_vals2          ; carrega o endereço do array de resultados da 2.ª sequência
    ldr r2, addr_k2             ; carrega o endereço do array k2
    ldr r3, addr_s2             ; carrega o endereço do array s2
    bl build_sequence           ; constrói a 2.ª sequência
    mov r5, r0                  ; guarda em r5 o número de elementos escritos

    mov r0, #50                 ; coloca 50 como valor inicial da 3.ª sequência
    ldr r1, addr_vals3          ; carrega o endereço do array de resultados da 3.ª sequência
    ldr r2, addr_k3             ; carrega o endereço do array k3
    ldr r3, addr_s3             ; carrega o endereço do array s3
    bl build_sequence           ; constrói a 3.ª sequência
    mov r6, r0                  ; guarda em r6 o número de elementos escritos

    ldr r0, addr_n1             ; carrega o endereço da variável n1
    str r4, [r0]                ; guarda em n1 o número de elementos da 1.ª sequência

    ldr r0, addr_n2             ; carrega o endereço da variável n2
    str r5, [r0]                ; guarda em n2 o número de elementos da 2.ª sequência

    ldr r0, addr_n3             ; carrega o endereço da variável n3
    str r6, [r0]                ; guarda em n3 o número de elementos da 3.ª sequência

end_main:
    b end_main                  ; loop infinito no fim do programa

; =========================================================
; ENDEREÇOS
; =========================================================
addr_k1:    .word array_k1      ; endereço base de array_k1
addr_s1:    .word array_s1      ; endereço base de array_s1
addr_vals1: .word array_vals1   ; endereço base de array_vals1

addr_k2:    .word array_k2      ; endereço base de array_k2
addr_s2:    .word array_s2      ; endereço base de array_s2
addr_vals2: .word array_vals2   ; endereço base de array_vals2

addr_k3:    .word array_k3      ; endereço base de array_k3
addr_s3:    .word array_s3      ; endereço base de array_s3
addr_vals3: .word array_vals3   ; endereço base de array_vals3

addr_n1:    .word n1            ; endereço da variável n1
addr_n2:    .word n2            ; endereço da variável n2
addr_n3:    .word n3            ; endereço da variável n3
