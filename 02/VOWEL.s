


which_vowel:
    mov r2, #'a'
    cmp r0, r2
    bne case_e
    mov r1, #1
    b end_case
case_e:
    mov r2, #'e'
    cmp r0, r2
    bne case_i
    mov r1, #2
    b end_case
case_i:
    mov r2, #'i'
    cmp r0, r2
    bne case_o
    mov r1, #3
    b end_case
case_o:
    mov r2, #'o'
    cmp r0, r2
    bne case_u
    mov r1, #4
    b end_case
case_u:
    mov r2, #'u'
    cmp r0, r2
    bne case_default
    mov r1, #5
    b end_case
case_default:
    mov r1, #0xFF
    movt r1, #0xFF
end_case:
    mov r0, r1

    mov pc, lr
