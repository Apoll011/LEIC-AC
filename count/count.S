.equ SIZE, 5
.equ STACK_SIZE, 64

.text
    b program
    b .

program:
    ldr	sp, addressof_stack
    ldr	pc, addressof_main

addressof_stack:
	.word	stack_top
addressof_main:
    .word   main

; r0 = char letter, r1 = i
witch_vowel:
    case_a:
        mov r2, #'a'
        cmp r0, r2
        bne case_e
        mov r1, #0
        b switch_end
    case_e:
        mov r2, #'e'
        cmp r0, r2
        bne case_i
        mov r1, #1
        b switch_end
    case_i:
        mov r2, #'i'
        cmp r0, r2
        bne case_o
        mov r1, #2
        b switch_end
    case_o:
        mov r2, #'o'
        cmp r0, r2
        bne case_u
        mov r1, #3
        b switch_end
    case_u:
        mov r2, #'u'
        cmp r0, r2
        bne switch_default
        mov r1, #4
        b switch_end
    switch_default:
        mov r1, #0xFF
        movt r1, #0xFF
    switch_end:
        mov r0, r1
        mov pc, lr

; r0/r4 = char phrase [] , r1 = uint16_t max_letters , r2 = uint16_t occurrences [5], r5 = i, r3/r6 = temp
vowel_histogram:
    push lr
    push r6
    push r5
    push r4

    mov r4, r0

    mov r5, #0              ; i = 0

    vowel_histogram_for_start:
        ldrb r0, [r4, r5]
        mov r6, #'\0'

        cmp r0, r6
        beq vowel_histogram_for_ret

        cmp r5, r1
        bhs vowel_histogram_for_ret 

        bl witch_vowel
        add r3, r0, #1
        beq vowel_histogram_for_pre_restart

        lsl r0, r0, #2
        ldrb r3, [r2, r0]
        add r3, r3, #1
        strb r3, [r2, r0]

    vowel_histogram_for_pre_restart:
        add r5, r5, #1          ; i++
        b vowel_histogram_for_start

    vowel_histogram_for_ret:
        pop r4
        pop r5
        pop r6
        pop pc

main:
    ldr r0, phrase_addr
    mov r1, #7
    ldr r2, occurrences_addr

    bl vowel_histogram

    b .    

phrase_addr:
    .word phrase
occurrences_addr:
    .word phrase

.data
    phrase:
        .asciz "hello, world"
        .align
    occurrences:
        .space SIZE * 2

.stack
.space STACK_SIZE
stack_top:
