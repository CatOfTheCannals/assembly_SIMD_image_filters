%define PI 3.14159

global Manchas_asm
extern printf

section .rodata

dos: dd 2.0, 2.0, 2.0, 2.0
pi: dd 3.14159, 3.14159, 3.14159, 3.14159 
cincuenta: dd 50.0, 50.0, 50.0, 50.0
veinticinco: dd 25.0, 25.0, 25.0, 25.0
;mascara: db 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0xff, 0xff, 0x02, 0x03, 0x02, 0x03, 0x02, 0x03, 0xff, 0xff 
;mascara2: db 0x04, 0x05, 0x04, 0x05, 0x04, 0x05, 0xff, 0xff, 0x06, 0x07, 0x06, 0x07, 0x06, 0x07, 0xff, 0xff    

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
	;movdqu xmm14, [mascara]
	;movdqu xmm15, [mascara]
	mov r14d, edx; R14d para WIDTH
	mov r15d, ecx; R15d para HEIGHT
	xor rbx, rbx
	mov ebx, dword [rbp + 16]; ebx = n
	xor edx, edx
	xor rcx, rcx
	xor r12, r12; Iterador filas - i
	xor r13, r13; Iterador columnas - j
	.rowLoop:
		.colLoop:
			mov ecx, 3
			.loopJmodN:
				mov eax, r13d
				xor rdx, rdx
				div ebx
				cvtsi2ss xmm0, edx
				pslldq xmm0, 4
				inc r13
				loop .loopJmodN
			mov eax, r13d
			xor rdx, rdx
			div ebx
			cvtsi2ss xmm0, edx
			inc r13
			;xmm0 == ||(float)(j mod n) | (float)((j + 1) mod n) | (float)((j + 2) mod n) | (float)((j + 3) mod n)||	
			cvtsi2ss xmm1, ebx; xmm1 = (float) n
			shufps xmm1, xmm1, 0
			divps xmm0, xmm1; xmm0 == ||(float)(j mod n) / n | (float)((j + 1) mod n) / n|
			;(float)((j + 2) mod n) / n | (float)((j + 3) mod n) / n||
			mulps xmm0, xmm10; xmm0 == ||(float)(j mod n) / n * 2 * PI| (float)((j + 1) mod n) / n * 2 * PI|
			;(float)((j + 2) mod n) / n * 2 * PI| (float)((j + 3) mod n) / n * 2 * PI||
			;Aplico cos
			;En xmm2 voy a acumular los cos
			mov ecx, 3
			.loopCos:
				finit
				movd [rbp - 8], xmm0
				fld dword [rbp - 8]
				fcos
				fst dword [rbp - 8]
				movd xmm3, [rbp - 8]
				movss xmm2, xmm3
				psrldq xmm0, 4
				pslldq xmm2, 4
				loop .loopCos
			finit 
			movd [rbp - 8], xmm0
			fld dword [rbp - 8]
			fcos
			fst dword [rbp - 8]
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
			divss xmm2, xmm1; xmm2 == (float)(i mod n) / n
			mulss xmm2, xmm10; xmm2 == (float)(i mod n) / n * 2 * pi
			finit
			movd [rbp - 8], xmm2
			fld dword [rbp - 8]
			fsin
			fst dword [rbp - 8]
			movd xmm2, [rbp - 8]
			shufps xmm2, xmm2, 0
			;xmm2 = ||sin((float)(i mod n) / n * 2 * pi) | sin((float)(i mod n) / n * 2 * pi) 
			;| sin((float)(i mod n) / n * 2 * pi) | sin((float)(i mod n) / n * 2 * pi) ||
			mulps xmm0, xmm2
			mulps xmm0, xmm7
			subps xmm0, xmm4
			mov ecx, 3
			.loopIntCast:
				cvtss2si r11d, xmm0
				movd xmm3, r11d
				movss xmm2, xmm3; Truco para evitar el zero clear de movd, no se me ocurrió otra solución
				pslldq xmm2, 4
				psrldq xmm0, 4
				loop .loopIntCast
			cvtss2si r11d, xmm0
			movd xmm3, r11d
			movss xmm2, xmm3; Truco para evitar el zero clear de movd, no se me ocurrió otra solución
			pshufd xmm0, xmm2, 0x1b
			;xmm0 == ||x_0 | x_1 | x_2 | x_3||
			;---------------------------------
			movdqu xmm1, [rdi];xmm1 == ||a3|r3|g3|b3||a2|r2|g2|b2||a1|r1|g1|b1||a0|r0|g0|b0||
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
			movdqu [rsi], xmm3
			;---------------------------------
			add rdi, 16
			add rsi, 16
			cmp r13d, r14d
			jne .colLoop
		xor r13, r13
		inc r12
		cmp r12d, r15d
		jne .rowLoop 
	pop r15
	pop r14
	pop r13
	pop r12
	add rsp, 16
	pop rbp
	ret
