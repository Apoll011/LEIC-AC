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


; R0 = M...R1 = m
multiply:
    push r5             ; Save previous values of the temp registers
    push r4
    mov r5, #0          ; Add 0 into register 5

    cmp     r0, r1      ; Compare r0 and r1, if r0 is smaller switch it with r1, to optimize the code
    bhs     end_check_multipliers
    mov     r3, r0      ; Switch Using r3 as temp value 
    mov     r0, r1
    mov     r1, r3

end_check_multipliers:
    mov     r3, r0      ; Move the M into r3 so r0 is used as lower part of the return

    mov     r4, r5      ; Initialize lower and higher bits parts as zero
    mov     r0, r5

    cmp     r1, r5      ; If m is 0 end
    beq     while_end

while:
    
    add     r0, r0, r3  ; Add to r0 the value of r0 plus M
    adc     r4, r4, r5  ; If overflows add the carry value untom r4 and r5 (witch is Zero)

    sub     r1, r1, #1  ; Subtract 1 from m
    cmp     r1, r5      ; If m is 0 end
    bzc     while       ; Else continue

while_end:
    pop r4              ; Retrive value from stack
    pop r5

    mov     r1, r4      ; Nove higher part of the 32 bit untom r1
    mov     pc, lr      ; return


; R0 = Value, R1=min, R2 = max
clamp_value:
    cmp r0, r1          ; Compare the R0 and R1
    bhs check_max       ; if R0 is smaller return r1
    mov r0, r1
    b end_clamp
check_max:              ; If R0 is greater than R1
    cmp r2, r0          ; COmpare with r2
    bhs end_clamp
    mov r0, r2          ; Return r2
end_clamp:
    mov pc, lr          ; Return  original r0 if not changed


scale_value:
    push lr             ; Save into Stack
    push r4
    push r5
    push r6

    mov r5, #0xFF       ; Temp values for calculations
    mov r4, #0

    and r1, r1, r5      ; r1(k_ext) = r1(k) & 0xFF ;
    bl multiply         ; r1-r0(prod) = umull ( r0(v), r1 ) ;

    cmp r2, r4          ; s(r2) - 0
    beq end_if          ; Z != 0
    and r2, r2, r5      ; r2 = r2 & 0xFF ;  
                    
    mov r4, r2          ; temp s
    mov r6, #1          ; Shifted 1
shifting_left:          ; Shift temp s times the 1
    sub r4, r4, #1
    beq end_shifting_left
    lsl r6, r6, #1
    b shifting_left 
end_shifting_left:
    add r0, r0, r6      ; Adds the r6 shifted value untom r0, and the carry unto r1
    adc r1, r1, r4      ; add the 0 from r4 and the carry
shifting_right:
    sub r2, r2, #1      ; Shifts r1-r0 s times
    beq end_if
    lsr r1, r1, #1
    rrx r0, r0
    b shifting_right
end_if:
    and r0, r0, r5      ; r0(prod_s) = r0 & 0xFF;
    mov r1, #VAL_MIN
    mov r2, r0
    bl clamp_value       ; r0(prod_c) = clamp_value ( r0 , #VAL_MIN , r2 ) ;   

    ; return r0 ;  
    pop r6
    pop r5          
    pop r4
    pop pc

build_sequence:
    push lr
    push r4
    push r5
    push r6
    push r7

    mov r7, #0

    mov r4, #0 ; i = 0;

    ldr r5, [r0, r4]

build_while:
    ldr r6, [r3, r4]
    cmp r6, r7
    beq end_build_while

    push r0
    push r1
    push r2
    
    ldr r0, [r1, r4]
    ldr r1, [r2, r4]
    ldr r2, [r3, r4]
    
    add r4, r4, #1

    bl scale_value
    str r0, [r1, r4]

    pop r2
    pop r1
    pop r0

    b build_while

end_build_while:
    mov r0, r4
    add r0, r0, #1
    pop r7
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


