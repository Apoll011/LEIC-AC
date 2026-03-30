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

    mov r0, #0x64 ; v_init = 100
    ldr r1, array_vals1_addr ; v[] = array_vals1
    ldr r2, array_k1_addr ; k[] = array_k1
    ldr r3, array_s1_addr ; s[] = array_s1
    bl build_sequence
    mov r7, r0

    mov r0, #0x0A ; v_init = 10
    ldr r1, array_vals2_addr ; v[] = array_vals2
    ldr r2, array_k2_addr ; k[] = array_k2
    ldr r3, array_s2_addr ; s[] = array_s2
    bl build_sequence
    mov r8, r0

    mov r0, #0x32 ; v_init = 50
    ldr r1, array_vals3_addr ; v[] = array_vals3
    ldr r2, array_k3_addr ; k[] = array_k3
    ldr r3, array_s3_addr ; s[] = array_s3
    bl build_sequence
    mov r9, r0
    b .

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


array_k1_addr:
    .word array_k1
array_s1_addr:
    .word array_s1
array_vals1_addr:
    .word array_vals1
array_k2_addr:
    .word array_k2
array_s2_addr:
    .word array_s2
array_vals2_addr:
    .word array_vals2
array_k3_addr:
    .word array_k3
array_s3_addr:
    .word array_s3
array_vals3_addr:
    .word array_vals3
build_sequence_addr:
    .word build_sequence


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
    and r1, r1, r5      ; r0(prod_s) = r0 & 0xFF;
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

    str r0, [r1, #0] ; v[0] = v_init

build_while:
    ldr r6, [r3, r4]    ; s[i]
    cmp r6, r7          ; if s[i] == 0 end
    beq end_build_while

    push r0
    push r1
    push r2
    
    ldr r0, [r1, r4] ; v[i]
    ldr r1, [r2, r4] ; k[i]
    ldr r2, [r3, r4] ; s[i]
    
    add r4, r4, #1 ; i++

    bl scale_value      ; scale_value ( v[i] , k[i] , s[i] ) ;
    str r0, [r1, r4]    ; v[i] = scale_value ( v[i] , k[i] , s[i] ) ;   

    pop r2
    pop r1
    pop r0

    b build_while

end_build_while:
    mov r0, r4      ; move i into r0 to return the number of elements in the sequence
    add r0, r0, #1  ; add 1 to i to return the number of elements in the sequence
    pop r7
    pop r6
    pop r5
    pop r4
    pop pc

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


