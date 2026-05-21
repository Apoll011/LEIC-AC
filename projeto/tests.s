.text
    mov r0, #(LED0_MASK | LED1_MASK | LED2_MASK | LED3_MASK)
    bl clear
    
    mov r0, #(LED0_MASK | LED1_MASK | LED2_MASK | LED3_MASK)
    mov r1, #LED_RED
    bl led
    
    mov r0, #14
    bl sleep
    
    mov r0, #(LED0_MASK | LED1_MASK | LED2_MASK | LED3_MASK)
    bl clear
    
    mov r4, #0x0F
	mov r6, #0x03
   
	mov r5, #0
p1:
	bl	inport_read
    mvn r0, r0
	and r0, r0, r4
	bne pressed
	b p1
pressed:
	add r5, r5, #1
	and r1, r5, r6
	bl led
    mov r0, #8
    bl sleep
	b p1


    mov r6, #0b01100000
loop:
    bl	inport_read
    mov r5, r0
    lsr r2, r0, #7
    and r0, r0, r4
    mvn r0, r0
    and r2, r2, r2
    bne clear_r
    mov r1, #LED_YELLOW

    and r1, r5, r6
    lsr r1, r1, #5
    bl led
    b	loop
clear_r:
    bl clear
    b loop



test1:
    mov r0, #(LED0_MASK | LED1_MASK)
	mov r1, #LED_RED
    bl led
    mov r0, #LED0_MASK
    bl clear
    mov r0, #(LED0_MASK | LED2_MASK)
    mov r1, #LED_GREEN
    bl led
