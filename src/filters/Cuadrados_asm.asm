
section .rodata
mask: db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00
masktest: dq 0xFFFFFFFFFFFFFFFF,0xFFFFFFFFFFFFFFFF
str: db 'paso',10,0

section .text
extern printf
%macro map 4 
	;NO USAR RDX COMO PARAMETRO
	;(i,j) -> i*w*4+j*4
	; rx i 		    : %1
	; rx j 		    : %2
	; rx w          : %3
	; rx result		: %4
	
	; modifies			: %4
	push rax
	push rdx
	xor rdx,rdx
	mov rax,%1
	mul %3
	pop rdx
	add rax,%2
	shl rax,2
	mov %4,rax
	pop rax

%endmacro

%macro pushxmm 1
	sub rsp,16
	movdqu [rsp],%1
%endmacro

%macro popxmm 1
	movdqu %1,[rsp]
	add rsp,16
%endmacro


%macro debug 0
	push r8
	push r9
	push r10
	push r11

	push rax
	push rdx
	push rcx
	push rsp
	push rbp
	push rdi
	push rsi

	pushxmm xmm0
	pushxmm xmm1

	mov rdi,str
	call printf

	popxmm xmm1
	popxmm xmm0

	pop rsi
	pop rdi
	pop rbp
	pop rsp
	pop rcx
	pop rdx
	pop rax

	pop r11
	pop r10
	pop r9
	pop r8
%endmacro

global Cuadrados_asm
Cuadrados_asm:
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
	sub r10,4
	mov r11,rdx							 ;r11 es width
	mov r13,rdx                          ;uso r13 para la macro, pues usa rdx
	sub r11,4
	mov r12,4                            ;r12 es i                  
    .loop_i:
        cmp r12,r10
        je .fin_i
        mov rbx,4                            ;rbx es j  
        .loop_j:
            cmp rbx,r11
            je .fin_j
            mov r9,r12                       ;experimentacion: hacer un loop vs loop unrolling (prediccion)
            map r9,rbx,r13,r15                     
            movdqu xmm0,[rdi+r15]            ;leo de src el i j
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15] 
            pmaxub xmm0,xmm1
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15]
            pmaxub xmm0,xmm1
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15]
            pmaxub xmm0,xmm1

            movdqu xmm1,xmm0                 ;xmm0: max1 | max2 | max3 | max4
            pslldq xmm1,8                    ;xmm1: max3 | max4 |   0  |   0
            pmaxub xmm0,xmm1                 ;xmm0: max(max1,max3) | max(max2,max4) |  ~  |  ~  
            movdqu xmm1,xmm0
            pslldq xmm1,12                   ;xmm1: max(max2,max4) | ~ | ~ | ~ 
            pmaxub xmm0,xmm1                 ;xmm0: max(max(max2,max4) , max(max1,max3)) | ~ | ~ | ~
            ;por xmm0,[mask]
            psrldq xmm0,12
            map r12,rbx,r13,r15
            movd [rsi+r15],xmm0                              

            inc rbx
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

