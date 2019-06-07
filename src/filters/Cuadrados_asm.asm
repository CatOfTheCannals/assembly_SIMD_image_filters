section .rodata
ALIGN 16
mask: db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF
maskzeros: db 0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF
masktest: dq 0xFFFFFFFFFFFFFFFF,0xFFFFFFFFFFFFFFFF
maskzero: db 0x0000000000000000,0x0000000000000000
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
	mov r10,rcx			                     ;r10 es height
	sub r10,4
	mov r11,rdx		                         ;r11 es width
	mov r13,rdx                              ;uso r13 para la macro, pues usa rdx
	sub r11,4
	mov r12,4                                ;r12 es i 
    movdqa xmm3,[mask]        
    movdqa xmm4,[maskzeros]         
    .loop_i:                                 ;iteramos sobre cada pixel de la imagen 
        cmp r12,r10
        je .fin_i
        mov rbx,4                            ;rbx es j  
        .loop_j:
            cmp rbx,r11
            je .fin_j
            mov r9,r12                       ;experimentacion: hacer un loop vs loop unrolling (prediccion)
            map r9,rbx,r13,r15               ;utilizamos una macro para poder obtener en r15 el offset para acceder al i,j deseado    
            movdqu xmm0,[rdi+r15]            ;obtenemos 4 pixeles del i,j
            inc r9                           ;en las siguientes iteraciones buscamos cada fila del cuadrado 4x4
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15] 
            pmaxub xmm0,xmm1                 ;al obtener una fila calculamos el maximo byte a byte contra la primer fila
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15]
            pmaxub xmm0,xmm1                 ;volvemos a calcular el maximo con la tercer fila
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15]
            pmaxub xmm0,xmm1                 ;por ultimo calculamos el maximo con la cuarta fila
                                             ;en xmm0 quedan los maximos byte a byte de las cuatro filas 
            movdqu xmm1,xmm0                 ;xmm0: max1 | max2 | max3 | max4                lo muevo a una variable auxiliar
            pslldq xmm1,8                    ;xmm1: max3 | max4 |   0  |   0                 shift para subir la parte baja
            pmaxub xmm0,xmm1                 ;xmm0: max(max1,max3) | max(max2,max4) |  ~  |  ~   resultado de aplicar nuevamente maximo byte a byte
            movdqu xmm1,xmm0
            pslldq xmm1,4                    ;xmm1: max(max2,max4) | ~ | ~ | ~               shifteamos una vez mas para volve a aplicar la instruccion
            pmaxub xmm0,xmm1                 ;xmm0: max(max(max2,max4) , max(max1,max3)) | ~ | ~ | ~  finalmente lo que se obtiene es el maximo entre cada pixel dentro del cuadrado 
            por xmm0,xmm3
            psrldq xmm0,12                   ;queremos que el calculo este en la parte baja del registro para poder escribirlo con un movd
            map r12,rbx,r13,r15              ;calculamos donde deberiamos escribir el resultado
            movd [rsi+r15],xmm0              ;escribimos en destino, la parte baja               

            inc rbx
            jmp .loop_j
        .fin_j:
        inc r12
        jmp .loop_i
    .fin_i:
;EL SIGUIENTE CODIGO ES PARA REALIZAR EL MARCO NEGRO. 
    mov r12,0                                ;r12 es k
    .loop_k:
    	cmp r12,4
    	je .fin_k
    	mov rbx,0                            ;rbx es l 
    		.loop_l:
    			cmp rbx,r13
    			je .fin_l

    			map r12,rbx,r13,r15
    			movdqu xmm0,xmm4
    			movdqu [rsi+r15],xmm0

    			add rbx,4
    			jmp .loop_l
    		.fin_l:
    	inc r12
    	jmp .loop_k
    .fin_k:

    mov r12,0                                ;r12 es 'i' desde 0
    .loop_m:
    	cmp r12,r10                          ;r10 es height -4
    	je .fin_m
 		map r12,r11,r13,r15                  ;m['i'][with-4]
		movdqu xmm0,xmm4
		movdqu [rsi+r15],xmm0
    	inc r12
    	jmp .loop_m
    .fin_m:

    mov r12,r10                                ;r12 es 'i'
    .loop_n:
    	cmp r12,rcx
    	je .fin_n
    	mov rbx,0                            ;rbx es l 
    		.loop_o
    			cmp rbx,r13
    			je .fin_o

    			map r12,rbx,r13,r15
    			movdqu xmm0,xmm4
    			movdqu [rsi+r15],xmm0

    			add rbx,4
    			jmp .loop_o
    		.fin_o:
    	inc r12
    	jmp .loop_n
    .fin_n:

    mov r12,4                                ;r12 es 'i' desde 0
    .loop_p:
    	cmp r12,r10                          ;r10 es height -4
    	je .fin_p
    	mov r11,0
 		map r12,r11,r13,r15                  ;m['i'][with-4]
		movdqu xmm0,xmm4
		movdqu [rsi+r15],xmm0
    	inc r12
    	jmp .loop_p
    .fin_p:


    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
	ret

