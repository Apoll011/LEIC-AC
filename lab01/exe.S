.equ SIZE, 5
.equ STACK_SIZE, 64
.equ VAL_MIN, 0x0005

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

main:

.data
    array_k1:
        .byte  205, 154, 102, 51, 0
        .align
    array_s1:  
        .byte  8, 8, 8, 8, 0
        .align
    array_vals1:
        .space 6
        .align

    array_k2:
        .byte   35, 38, 42, 45, 0
        .align 
    array_s2:  
        .byte  5, 5, 5, 5, 0
        .align
    array_vals2:
        .space 6
        .align

    array_k3:
        .byte   205, 154, 0, 45, 35, 0
        .align 
    array_s3:  
        .byte   8, 8, 0, 5, 5, 0
        .align
    array_vals3:
        .space 7
        .align

.stack
.space STACK_SIZE
stack_top:
