global _start

SECTION .data
	hello db "Hello World!", 10
	hello_len equ $-hello

SECTION .text

_start:
	mov rax, 1
	mov rdi, 1
	mov rsi, hello
	mov rdx, hello_len
	syscall

	mov rax, 60
	mov rdi, 0
	syscall

