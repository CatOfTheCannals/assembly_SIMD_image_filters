section .rodata
ALIGN 16
black_pixel: db  0x00,0x00,0x00,0xff

centro_izq_por_9: dw 0x0000,0x0000,0x0000,0x0000,0x0009,0x0009,0x0009,0x0000
centro_der_por_9: dw 0x0009,0x0009,0x0009,0x0000,0x0000,0x0000,0x0000,0x0000

alphas_saturados: dw  0x0000,0x0000,0x0000,0x00ff,0x0000,0x0000,0x0000,0x00ff


section .text

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

global Sharpen_asm
Sharpen_asm:
    ; el loop va a levantar una matriz de 3x4 pixeles, la cual tiene info suficiente para procesar dos pixeles contiguos
    ; para esto se usaran tres registros xmm, uno por cada fila

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

    mov r10, rcx ; r10 = height
    mov r11, rdx ; r11 = width
    mov r13, rdx ; uso r13 para la macro, pues usa rdx
    mov r14d, dword [black_pixel]

    mov rbx, 0 ; rbx es j
    .horizontal_blacks:
        cmp rbx, r11
        je .end_horizontal_blacks

        mov r9, 0 ; escribir el pixel de la primera fila
        map r9,rbx,r13,r15
        mov dword [rsi+r15], r14d

        mov r9, r10
        dec r9 ; escribir el pixel de la ultima fila
        map r9,rbx,r13,r15
        mov dword [rsi+r15], r14d

        inc rbx
        jmp .horizontal_blacks
    .end_horizontal_blacks:

    mov r12, 1 ; r12 es i
    dec r10 ; no queremos escribir ni la primera ni la ultima fila
    .vertical_blacks:
        cmp r12, r10
        je .end_vertical_blacks

        mov r9,r12
        mov rbx, 0 ; escribir el primer pixel de la fila
        map r9,rbx,r13,r15
        mov dword [rsi+r15], r14d

        mov rbx, r11
        dec rbx ; escribir el ultimo pixel de la fila
        map r9,rbx,r13,r15
        mov dword [rsi+r15], r14d

        inc r12
        jmp .vertical_blacks
    .end_vertical_blacks:
    inc r10 ; restaurar r10

    mov rbx, 0 ; rbx es j
    sub r10, 2 ; queremos bajar hasta dos pixeles antes del fin
    sub r11, 2 ; queremos ir a la derecha hasta cuatro pixeles antes del fin
    mov r12, 0 ; r12 es i
    .loop_j:
        cmp rbx,r11 ; j == 1020 ; ojo este comentario esta jarcodeado
        je .fin_j
        mov r12, 0 ; rbx es j
        .loop_i:
            cmp r12, r10 ; i == 637 ; ojo este comentario esta jarcodeado
            je .fin_i

            ; leer primera fila: xmm0 = src[i][j:j+4]
            mov r9,r12
            map r9,rbx,r13,r15
            movdqu xmm0,[rdi+r15]

            ; leer segunda fila: xmm1 = src[i+1][j:j+4]
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm1,[rdi+r15]

            ; leer tercera fila: xmm2 = src[i+2][j:j+4]
            inc r9
            map r9,rbx,r13,r15
            movdqu xmm2,[rdi+r15]

            ; unpack primera fila high y low
            pxor xmm4, xmm4
            movdqu xmm3, xmm0
            punpcklbw xmm0, xmm4 ; xmm0 contiene el low de la primera fila en words
            punpckhbw xmm3, xmm4 ; xmm3 contiene el high de la primera fila en words

            ; unpack segunda fila high y low
            movdqu xmm5, xmm1
            punpcklbw xmm1, xmm4 ; xmm1 contiene el low de la segunda fila en words
            punpckhbw xmm5, xmm4 ; xmm5 contiene el high de la segunda fila en words

            ; unpack tercera fila high y low
            movdqu xmm6, xmm2
            punpcklbw xmm2, xmm4 ; xmm2 contiene el low de la segunda fila en words
            punpckhbw xmm6, xmm4 ; xmm6 contiene el high de la segunda fila en words

            ; ----- primer pixel -----

            ; sumamos los pixeles que no son el pixel central

            ; sumar los primeros dos pixeles de 1ra y 3ra filas ;
            movdqu xmm7, xmm0
            paddusw xmm7, xmm2

            ; sumar high y low de xmm7, el resultado queda en el low de xmm7 (en gdb el low se printea a la izq del reg)
            movdqu xmm8, xmm7
            psrldq xmm8, 8
            paddusw xmm7, xmm8

            ; xmm8_low = sum(src[i:i+3][j+2])
            pxor xmm8, xmm8
            paddusw xmm8, xmm3
            paddusw xmm8, xmm5
            paddusw xmm8, xmm6

            ; xmm8_high += src[i+1][j]
            paddusw xmm8, xmm1

            paddusw xmm7, xmm8 ; ==> xmm7_low = suma(pixeles_que_no_son_el_central)

            movdqa xmm10, [centro_izq_por_9] ; al multiplicar por esta mascara tambien se pone alpha en cero
            movdqu xmm11, xmm1
            pmullw xmm11, xmm10 ; ==> xmm11_high = pixel_central_izquierdo * 9

            pslldq xmm7, 8 ; ==> xmm7_high = suma(pixeles_que_no_son_el_central)
            psubusw xmm11, xmm7 ; xmm11_high = pixel_central * 9 - suma(pixeles_que_no_son_el_central)

            movdqa xmm10, [alphas_saturados]
            paddusw xmm11, xmm10

            ; ----- segundo pixel -----

            ; sumamos los pixeles que no son el pixel central

            ; sumar los ultimos dos pixeles de 1ra y 3ra filas ;
            movdqu xmm7, xmm3
            paddusw xmm7, xmm6

            ; sumar high y low de xmm7, el resultado queda en el high de xmm7
            movdqu xmm8, xmm7
            pslldq xmm8, 8
            paddusw xmm7, xmm8

            ; xmm8_high = sum(src[i:i+3][j+1])
            pxor xmm8, xmm8
            paddusw xmm8, xmm0
            paddusw xmm8, xmm1
            paddusw xmm8, xmm2

            ; xmm8_high += src[i+1][j]
            paddusw xmm8, xmm5

            paddusw xmm7, xmm8 ; ==> xmm7_high = suma(pixeles_que_no_son_el_central)


            movdqa xmm10, [centro_der_por_9] ; al multiplicar por esta mascara tambien se pone alpha en cero
            pmullw xmm5, xmm10 ; ==> xmm1_low = pixel_central_derecho * 9


            psrldq xmm7, 8 ; ==> xmm7_low = suma(pixeles_que_no_son_el_central)
            psubusw xmm5, xmm7 ; xmm5_low = pixel_central * 9 - suma(pixeles_que_no_son_el_central)

            movdqa xmm10, [alphas_saturados]
            paddusw xmm5, xmm10

            ; ----- escribir ambos pixeles en memoria -----

            ; empaquetar el resultado a bytes

            packuswb xmm11, xmm5 ; xmm5 = | basura | pixel_izq | pixel_der | basura |

            psrldq xmm11, 4

            dec r9 ; apuntar a i a fila del medio
            inc rbx ; apuntar a j a segunda columna
            map r9,rbx,r13,r15
            dec rbx ; reestablecer j

            ; dest[i+1][j+1] = pixel_izq

            pextrq qword [rsi+r15], xmm11, 0

            inc r12
            jmp .loop_i

        .fin_i:
            add rbx, 2 ; j += 2 ya que insertamos 2 pixeles por loop
            jmp .loop_j
            
    .fin_j:


    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
	ret
