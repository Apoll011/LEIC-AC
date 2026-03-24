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

multiply:
    push r2
    mov r2, #0
    cmp     r0, r1
    bhs     end_check_multipliers
    mov     r3, r0
    mov     r0, r1
    mov     r1, r3
end_check_multipliers:
    mov     r3, r0
    mov     r4, r2
    mov     r0, r2

    cmp     r1, r2
    beq     while_end

while:
    add     r0, r0, r3
    adc     r4, r4, r2
    sub     r1, r1, #1
    cmp     r1, r2
    bzc     while

while_end:
    pop r2
    mov     r1, r4
    mov     pc, lr



clamp_value:
    ;mov r0, #'val
    ;mov r1, #min
    ;mov r2, #max
    cmp r0, r1
    bhs check_max
    mov r0, r1
    b end_clamp
check_max:
    cmp r2, r0
    bhs end_clamp
    mov r0, r2
end_clamp:
    mov pc, lr


scale_value:
    push lr
    push r4
    push r5
    push r6

    mov r5, #0xFF
    mov r4, #0

    and r1, r1, r5  ; r1(k_ext) = r1(k) & 0xFF ;
    bl multiply     ; r1-r0(prod) = umull ( r0(v), r1 ) ;

    cmp r2, r4      ; s(r2) - 0
    beq end_if      ; Z != 0
    and r2, r2, r5  ; r2 = r2 & 0xFF ;  
                    
    mov r4, r2      ; temp s
    mov r6, #1      ; Shifted 1
shiting_left:       ; Shift temp s times the 1
    sub r4, r4, #1
    beq end_shifting_left
    lsl r6, r6, #1
    b shiting_left 
end_shifting_left:
    add r0, r0, r6  ; Adds the r6 shifted value untom r0, and the carry unto r1
    adc r1, r1, r4  ; add 0 from r4 and the carry
shifting_right:
    sub r2, r2, #1  ; Shifts r1-r0 s times
    beq end_if
    lsr r1, r1, #1
    rrx r0, r0
    b shifting_right
end_if:
    and r0, r0, r5  ; r0(prod_s) = r0 & 0xFF;
    mov r1, #VAL_MIN
    mov r2, r0
    b clamp_value   ; r0(prod_c) = clamp_value ( r0 , #VAL_MIN , r2 ) ;   

    ; return r0 ;  
    pop r6
    pop r5          
    pop r4
    pop pc

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


