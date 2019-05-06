section .rodata
mask: db 0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF
maskRed: db 0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00
maskGreen: db 0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00
maskBlue: db 0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00


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
	mov r13,rdx
	sub r11,8
	sub r11,4
	mov r12,0                            ;r12 es i
	movdqu xmm3,[maskBlue]
	movdqu xmm5,[maskGreen]
	movdqu xmm6,[maskRed]
	movdqu xmm7,[mask]
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
		map r9,r8,r13,r15
		movdqu xmm0,[rdi+r15]		     ;xmm0 leo de src el [i+8] [j]
		sub r9,8                         ;en r9 -> i
		add r8,8                         ;en r8 -> j+8
		map r9,r8,r13,r15
		movdqu xmm1,[rdi+r15]            ;xmm1 leo de src el [i] [j+8]
		add r9,8
		map r9,r8,r13,r15
		movdqu xmm2,[rdi+r15]            ;xmm2 leo de src el [i+8][j+8]

		pand xmm0,xmm3                    ;and entre [i+8][j] vs maskblue me da xmm3 blue 0|blue 0|blue 0|blue 0
		pand xmm1,xmm5                    ;and entre [i][j+8] vs maskgreen me da xmm5 0green0|0green0|0green0|0green0
		pand xmm2,xmm6                    ;and entre [i+8][j+8] vs maskgreen me da xmm5 00red0|00red0|00red0|00red0

		por xmm0,xmm1                     ;or junta los valores que interesan
		por xmm0,xmm2
		por xmm0,xmm7                     ;pone el 255 en a

		map r12,rbx,r13,r15
		movdqu [rsi+r15],xmm0

		add rbx,4
		jmp .loop_j
	.fin_j:
	inc r12
	jmp .loop_i
.fin_i:

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
	ret


