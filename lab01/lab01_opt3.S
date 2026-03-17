; -----------------------------------------------------------------------------
; Ficheiro:  lab01.s
; Descricao: Codigo de suporte a realizacao da 1a atividade laboratorial de AC.
; Autor:     Tiago M Dias (tiago.dias@isel.pt)
; Data:      11-03-2022
; -----------------------------------------------------------------------------

	; r0 guarda o valor da variavel M
	; r1 guarda o valor da variavel m
	; r2 guarda o valor da variavel p
	; if (M < m) temp = m, m = M, M = temp
	; R4, R5, R4 diz se M é negativo, e R5 diz se m é negativo
	; temos o valor absoluto e fazemos normalemnte
	; no fim se pelo menos 1 é negativo invertemos o sinal... e se os 2 forem negatiovs nao fazemos nada
	;
	;
	;
	; r3 e utilizado para guardar valores temporariamente

	mov	r2, #0

check_M:
	lsr r4, r0, #15
	cmp r4, r2
	beq check_m
	mvn r0, r0
	add r0, r0, #1

check_m:
	lsr r5, r1, #15
	cmp r5, r2
	beq end_checks
	mvn r1, r1
	add r1, r1, #1

end_checks:
	cmp r0, r1
	bhs end_check_multipliers
	mov r3, r0
	mov r0, r1
	mov r1, r3

end_check_multipliers:
	cmp r0, r2
	beq while_end
	mov	r3, #0
while:
	cmp	r3, r1
	bhs	while_end
	add	r2, r2, r0
	sub	r1, r1, #1
	b	while
while_end:
	eor r4, r4, r5
	cmp r4, r3
	beq end
	mvn r2, r2
	add r2, r2, #1

end:
	b	.
