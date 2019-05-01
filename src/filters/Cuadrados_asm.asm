section .rodata
mask: db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00
masktest: dq 0xFFFFFFFFFFFFFFFF,0xFFFFFFFFFFFFFFFF

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
        map r9,rbx,rdx,r15                     
		movdqu xmm0,[rdi+r15]		     ;leo de src el i j
		inc r9
		map r9,rbx,rdx,r15
		movdqu xmm1,[rdi+r15] 
		pmaxub xmm0,xmm1
		inc r9
		map r9,rbx,rdx,r15
		movdqu xmm1,[rdi+r15]
		pmaxub xmm0,xmm1
		inc r9
		map r9,rbx,rdx,r15
		movdqu xmm1,[rdi+r15]
		pmaxub xmm0,xmm1

		movdqu xmm1,xmm0                 ;xmm0: max1 | max2 | max3 | max4
		psllq xmm1,1                     ;xmm1: max3 | max4 |   0  |   0
		pmaxub xmm0,xmm1                 ;xmm0: max(max1,max3) | max(max2,max4) |  ~  |  ~  
		movdqu xmm1,xmm0
		pslld xmm1,1                     ;xmm1: max(max2,max4) | ~ | ~ | ~ 
		pmaxub xmm0,xmm1	             ;xmm0: max(max(max2,max4) , max(max1,max3)) | ~ | ~ | ~
		por xmm0,[mask]
		psrld xmm0,3
		map r12,rbx,rdx,r15
		movd [rsi+r15],xmm0	                            

		inc rbx
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

;buemask: 1->no 0->si => 7mo bit un 0 prox 6 bits el indice
;pmaxsb xmm0,xmm1                 ;pone en xmm0 los maximos 2
;16bytes prepararB: db 0x00,0xFF,0xFF,0xFF,0x03,0xFF,0xFF,0xFF,0x06,0xFF,0xFF,0xFF,0x09,0xFF,0xFF,0xFF   00001001
;12345678 112345678\
