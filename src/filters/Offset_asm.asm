section .rodata
maskBlue: db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00


section .text
%macro map 4 
	;(i,j) -> i*w*4+j*4
	; rx i 		    : %1
	; rx j 		    : %2
	; rx w          : %3
	; rx result		: %4
	
	; modifies			: %4
	push rax
	mov rax,%1
	mul %3
	add rax,%2
	shl rax,2
	mov %4,rax
	pop rax

%endmacro

global Offset_asm
Offset_asm:
	push rbp
    mov rbp,rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

	;rsi dst matriz
	;rdi src matriz
	;edx width en pixeles
	;ecx height
	;r8d es src row size
	;r9d es dst row size
	mov r10,rcx							 ;r10 es height
	sub r10,8
	mov r11,rdx							 ;r11 es width
	sub r11,8
	sub r11,4
	mov r12,0                            ;r12 es i
.loop_i:
	cmp r12,r10                          ;i < height-8
	je .fin_i
	mov rbx,0                            ;rbx es j	
	.loop_j:
		cmp rbx,r11                      ;j < width-8-4 -> porque calculo en paralelo
		je .fin_j
		mov r9,r12                       ;en r9 -> i+8
		add r9,8
		mov r8,rbx                       ;en r8 -> j
		map r9,r8,r11,r15
		movdqu xmm0,[rdi+r15]		     ;xmm0 leo de src el [i+8] [j]
		sub r9,8                         ;en r9 -> i
		add r8,8                         ;en r8 -> j+8
		map r9,r8,r11,r15
		movdqu xmm1,[rdi+r15]            ;xmm1 leo de src el [i] [j+8]
		add r9,8
		map r9,r8,r11,r15
		movdqu xmm2,[rdi+r15]            ;xmm2 leo de src el [i+8][j+8]


		add rbx,4
	.fin_j:
	inc r12
.fin_i:

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
	ret
