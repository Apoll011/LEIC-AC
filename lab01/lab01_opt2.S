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
	;
	;
	;
	; r3 e utilizado para guardar valores temporariamente

multiply:
	mov	r2, #0

	cmp r0, r1
	bhs end_check_multipliers
	mov r3, r0
	mov r0, r1
	mov r1, r3

end_check_multipliers:
	cmp r0, r2
	beq while_end
while:
	mov	r3, #0
	cmp	r3, r1
	bhs	while_end
	add	r2, r2, r0
	sub	r1, r1, #1
	b	while
while_end:
	mov r0, r2
	mov pc, lr
