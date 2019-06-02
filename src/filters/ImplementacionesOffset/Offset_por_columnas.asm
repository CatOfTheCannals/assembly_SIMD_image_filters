section .rodata

extern printf

ALIGN 16
mask1: TIMES 4 db 0x00, 0xff, 0x00, 0x00
mask2: TIMES 4 db 0x00, 0x00, 0xff, 0x00
zeromask: TIMES 4 db 0x00, 0x00, 0x00, 0xff
debug: db 'i = %d, j = %d', 10, 0

global Offset_asm

section .text

%macro print 2
push rdi
push rsi
push rdx
push rcx
push r8
push r9
push r10
push r11
mov rdi, debug
mov esi, %1
mov edx, %2
call printf
pop r11
pop r10
pop r9
pop r8
pop rcx
pop rdx
pop rsi
pop rdi
%endmacro

Offset_asm:
;RDI = src
;RSI = dst
;EDX = width
;ECX = height 
;R8d = src_row_size
;R9d = dst_row_size
	push rbp
	mov rbp, rsp
	push r12
	push r13
	push r14
	push r15
	movdqa xmm6, [mask1]
	movdqa xmm7, [mask2]
	movdqa xmm8, [zeromask]

	;Armamos los bordes negros
	mov r13d, edx
	mov eax, ecx
	mov r12d, r8d
	sub eax, 8
	mul r12d
	mov edx, r13d
	mov r12, rax 
	mov r13, rsi
	xor r10, r10
	xor r11, r11
	;Bordes superior e inferior
	.loopi_bordeSupInf:
		.loopj_bordeSupInf:
			movdqu [r13], xmm8
			movdqu [r13 + r12], xmm8
			add r13, 16
			add r11, 4
			cmp r11d, edx
			jne .loopj_bordeSupInf
		xor r11, r11 
		inc r10
		cmp r10, 8
		jne .loopi_bordeSupInf
	mov r10, 8
	mov r11, rcx
	lea r12, [r11 + rdx - 8]
	mov r13, rsi
	;Bordes izquierdo y derecho
	.loop_bordeIzqDer:
		movdqu [r13], xmm8
		add r13, 16
		movdqu [r13], xmm8
		add r13, 16
		lea r13, [r13 + r8]
		sub r13, 64
		movdqu [r13], xmm8
		add r13, 16
		movdqu [r13], xmm8
		add r13, 16
		inc r10
		cmp r10, r11
		jne .loop_bordeIzqDer
	;Filtro Offset
	lea r12, [r8 * 8];
	lea r13, [r8 * 8 + 32]
	mov r14d, edx
	sub r14, 9; R14 = width - 9
	mov r15d, ecx
	sub r15, 9; R15 = height - 9
	mov r10, 8; R10 = i
	mov r11, 8; R11 = j
	lea rdi, [rdi + r8 * 8 + 32]
	lea rsi, [rsi + r8 * 8 + 32]
	mov rcx, rdi; src
	mov rdx, rsi; dst
	.loopj:
		.loopi:
			movdqu xmm1, [rdi + r12]; xmm1 = src[i+8][j] y los 3 píxeles que siguen. Necesario para BLUE.
			movdqu xmm2, [rdi + 32]; xmm2 = src[i][j+8] y los 3 píxeles que siguen. Necesario para GREEN.
			movdqu xmm3, [rdi + r13]; xmm3 = src[i+8][j+8] y los 3 píxeles que siguen. Necesario para RED.
			movdqu xmm0, xmm6
			pblendvb xmm1, xmm2, xmm0
			movdqu xmm0, xmm7
			pblendvb xmm1, xmm3, xmm0
			movdqu [rsi], xmm1
			add rdi, r8
			add rsi, r8
			inc r10
			cmp r10, r15
			jle .loopi
		mov r10, 8
		add rcx, 16
		add rdx, 16
		mov rdi, rcx
		mov rsi, rdx	
		add r11, 4
		cmp r11, r14
		jle .loopj 	
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbp
