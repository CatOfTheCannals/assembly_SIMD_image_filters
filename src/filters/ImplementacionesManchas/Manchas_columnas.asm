%define PI 3.14159


global Manchas_asm
extern printf

section .rodata

dos: dd 2.0, 2.0, 2.0, 2.0
pi: dd 3.14159, 3.14159, 3.14159, 3.14159 
cincuenta: dd 50.0, 50.0, 50.0, 50.0
veinticinco: dd 25.0, 25.0, 25.0, 25.0

section .text

Manchas_asm:
;Aridad: void Manchas_asm(uint8_t* src, uint8_t* dst, int width, int height, 
; int src_row_size, int dst_row_size, int n)
;RDI = src, RSI = dst, EDX = width, ECX = height
;R8D = src_row_size, R9D = dst_row_size, dword [RSP] = n

	push rbp
	mov rbp, rsp
	sub rsp, 16
	push r12
	push r13
	push r14
	push r15
	movdqu xmm7, [cincuenta]
	movdqu xmm4, [veinticinco]
	movdqu xmm5, [dos]
	movdqu xmm10, [pi]
	pxor xmm12, xmm12; Para que guarde 0 y unpackear más adelante
	mulps xmm10, xmm5
	mov r14d, edx; R14d para WIDTH
	mov r15d, ecx; R15d para HEIGHT
	xor rbx, rbx
	mov ebx, dword [rbp + 16]; ebx = n
	cvtsi2ss xmm13, ebx
	shufps xmm13, xmm13, 0
	divps xmm10, xmm13; xmm10 == ||2 * PI / n| 2 * PI / n | 2 * PI / n | 2 * PI / n||
	xor r12, r12; Iterador filas - i
	xor r13, r13; Iterador columnas - j
	xor r10, r10; Bytes por fila en src
	xor r11, r11; Bytes por fila en dst
	finit
	.colLoop:
		.rowLoop:
			mov ecx, 3
			.loopJmodN:
				mov eax, r13d
				xor rdx, rdx
				div ebx
				movd xmm1, edx
				movss xmm0, xmm1
				pslldq xmm0, 4
				inc r13
				loop .loopJmodN
			mov eax, r13d
			xor rdx, rdx
			div ebx
			movd xmm1, edx
			movss xmm0, xmm1
			cvtdq2ps xmm0, xmm0
			inc r13
			;xmm0 == ||(float)(j mod n) | (float)((j + 1) mod n) | (float)((j + 2) mod n) | (float)((j + 3) mod n)||
			mulps xmm0, xmm10; xmm0 == ||(float)(j mod n) / n * 2 * PI| (float)((j + 1) mod n) / n * 2 * PI|
			;(float)((j + 2) mod n) / n * 2 * PI| (float)((j + 3) mod n) / n * 2 * PI||

			;Aplico cos: Lo hago en forma de ciclo para reducir instrucciones
			;La última iteración se hace a mano para no shiftear de más
			;En xmm2 voy a acumular los cos
			mov ecx, 3; 3 iteraciones
			.loopCos:
				movd [rbp - 8], xmm0
				fld dword [rbp - 8]
				fcos
				fstp dword [rbp - 8]
				movd xmm3, [rbp - 8];Recordar que movd hace zero clear, por eso uso a xmm3 de intermediario
				movss xmm2, xmm3
				psrldq xmm0, 4
				pslldq xmm2, 4
				loop .loopCos
			movd [rbp - 8], xmm0
			fld dword [rbp - 8]
			fcos
			fstp dword [rbp - 8]
			movd xmm3, [rbp - 8]
			movss xmm2, xmm3
			;Reordeno xmm2 en xmm0
			pshufd xmm0, xmm2, 0x1b
			;xmm0 == ||cos((float)(j mod n) / n * 2 * PI)| cos((float)((j + 1) mod n) / n * 2 * PI)|
			;cos((float)((j + 2) mod n) / n * 2 * PI)| cos((float)((j + 3) mod n) / n * 2 * PI)||

			;Ahora armo sin((float)(i%n) / n * 2 * PI)
			mov eax, r12d
			xor rdx, rdx
			div ebx
			cvtsi2ss xmm2, edx
			mulss xmm2, xmm10; xmm2 == (float)(i mod n) / n * 2 * pi
			movd [rbp - 8], xmm2
			fld dword [rbp - 8]
			fsin
			fstp dword [rbp - 8]
			movd xmm2, [rbp - 8]
			shufps xmm2, xmm2, 0
			;xmm2 = ||sin((float)(i mod n) / n * 2 * pi) | sin((float)(i mod n) / n * 2 * pi) 
			;| sin((float)(i mod n) / n * 2 * pi) | sin((float)(i mod n) / n * 2 * pi) ||
			mulps xmm0, xmm2
			mulps xmm0, xmm7
			subps xmm0, xmm4
			cvtps2dq xmm0, xmm0
			;xmm0 == ||x_0 | x_1 | x_2 | x_3||
			sub r13, 4
			lea r11, [r10 + r13 * 4]

			movdqu xmm1, [rdi + r11];xmm1 == ||a3|r3|g3|b3||a2|r2|g2|b2||a1|r1|g1|b1||a0|r0|g0|b0||
			movdqu xmm3, xmm1
			punpcklbw xmm3, xmm12
			;xmm3 == ||a1 | r1 | g1 | b1 || a0 | r0 | g0 | b0 || //Tamaño word
			movdqu xmm8, xmm0
			packssdw xmm8, xmm8
			;xmm8 == ||x_0 | x_1 | x_2 | x_3||x_0 | x_1 | x_2 | x_3|| //Tamaño word
			pshuflw xmm8, xmm8, 0xff
			pshufhw xmm8, xmm8, 0xaa
			;xmm8 == || x_1 | x_1 | x_1 | x_1 || x_0 | x_0 | x_0 | x_0 || //Tamaño word
			pblendw xmm8, xmm12, 0x88
			;xmm8 == || 0 | x_1 | x_1 | x_1 || 0 | x_0 | x_0 | x_0 || //Tamaño word
			;pshufb xmm8, xmm14
			paddw xmm3, xmm8
			pxor xmm9, xmm9
			movdqa xmm11, xmm3
			pcmpgtw xmm11, xmm9;
			pand xmm3, xmm11

			movdqu xmm6, xmm1
			punpckhbw xmm6, xmm12
			;xmm3 == ||b3 | g3 | r3 | a3 || b2 | g2 | r2 | a2 || //Tamaño word
			movdqu xmm8, xmm0
			packssdw xmm8, xmm8
			;xmm8 == ||x_0 | x_1 | x_2 | x_3||x_0 | x_1 | x_2 | x_3|| //Tamaño word
			pshuflw xmm8, xmm8, 0x11
			pshufhw xmm8, xmm8, 0x00
			;xmm8 == || x_3 | x_3 | x_3 | x_3 || x_2 | x_2 | x_2 | x_2 || //Tamaño word
			pblendw xmm8, xmm12, 0x88
			;xmm8 == || 0 | x_3 | x_3 | x_3 || 0 | x_2 | x_2 | x_2 || //Tamaño word
			;pshufb xmm8, xmm15
			paddw xmm6, xmm8
			pxor xmm9, xmm9
			movdqa xmm11, xmm6
			pcmpgtw xmm11, xmm9
			pand xmm6, xmm11
			packuswb xmm3, xmm6
			movdqu [rsi + r11], xmm3
			;add rdi, 16
			;add rsi, 16
			add r10d, r9d 
			inc r12
			cmp r12d, r15d
			jne .rowLoop
		xor r10, r10
		xor r12, r12
		add r13, 4
		cmp r13d, r14d
		jne .colLoop 
	pop r15
	pop r14
	pop r13
	pop r12
	add rsp, 16
	pop rbp
	ret
