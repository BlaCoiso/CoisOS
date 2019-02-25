BITS 16
SECTION .text

ExecProgram: ;int ExecProgram(int argc, char* argv[], int startIP, int segment)
	;[BP+2] - Ret Addr
	;[BP+4] - argc
	;[BP+6] - argv
	;[BP+8] - startIP
	;[BP+10]- segment
	push BP
	mov BP, SP
	sub SP, 2
	;[BP-2] - Return value
	;TODO: Register interrupt handlers for invalid instructions and other exceptions
	;TODO: Make sure this doesn't get called if a program is already running
	;TODO: Allow this to execute more than one program
	mov CX, DS
	mov AX, KRN_SEG
	mov DS, AX
	mov [_ProgRetDS], CX
	mov [_ProgRetES], ES
	mov AX, [BP+2]
	mov [_ProgRetIP], AX
	mov AL, [_ScreenPage]
	mov [_ProgRetScrPage], AL
	pusha
	push PROG_STK_CHK4
	push PROG_STK_CHK3
	push PROG_STK_CHK2
	push PROG_STK_CHK1
	mov [_ProgStartSP], SP
	mov [_ProgStartBP], BP
	mov AX, [_ProgRetDS]
	push AX
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	mov AX, [BP+10]
	mov DS, AX
	call far [BP+8]
	mov CX, CS
	mov DS, CX
	mov SP, [_ProgStartSP]
	mov BP, [_ProgStartBP]
	mov [BP-2], AX
	pop AX
	pop BX
	pop CX
	pop DX
	cmp AX, PROG_STK_CHK1
	jne .stkChkFail
	cmp BX, PROG_STK_CHK2
	jne .stkChkFail
	cmp CX, PROG_STK_CHK3
	jne .stkChkFail
	cmp DX, PROG_STK_CHK4
	je .stkChkOK
.stkChkFail:
	call GetCursorAttribute
	mov [BP-4], AX
	push 3
	call SetScreenPage
	push 0x1F	;White on Blue
	call SetCursorAttribute
	call ClearScreen
	call GetScreenHeight
	shl AX, 7
	xor AL, AL
	push AX
	call SetCursorPos
	push _StkChkCorrupt
	call PrintTitle
.stkChkLoop:
	call GetKey
	call _ChrToUppercase
	cmp AL, 'R'
	je .cleanReboot
	cmp AL, 'C'
	je .continue
	cmp AL, 'H'
	je .halt
	jmp .stkChkLoop
.continue:
	call .screenClean
.stkChkOK:
	mov AX, [_ProgRetScrPage]
	xor AH, AH
	push AX
	call SetScreenPage
	popa
	mov AX, [_ProgRetIP]
	mov [BP+2], AX	;Make sure program returns back
	mov ES, [_ProgRetES]
	mov DS, [_ProgRetDS]
	mov AX, [BP-2]
	mov SP, BP
	pop BP
	ret 8
.screenClean:
	mov AX, [BP-4]
	push AX
	call SetCursorAttribute
	call ClearScreen
	mov AX, [_ProgRetScrPage]
	xor AH, AH
	push AX
	call SetScreenPage
	ret
.cleanReboot:
	call .screenClean
	xor AX, AX
	int 0x19
	hlt
.halt:
	cli
	hlt
	jmp .halt	;Make sure processor won't wake up again

SECTION .data
_StkChkCorrupt db 'WARNING: Stack was corrupted. (r)eboot, (c)ontinue, (h)alt', 0

SECTION .bss
PROG_STK_CHK1 EQU 0xB4D8
PROG_STK_CHK2 EQU 0xDEAD
PROG_STK_CHK3 EQU 0xCFAA
PROG_STK_CHK4 EQU 0x3A5F

;TODO: Allow multiple programs to be loaded, make program entry structure, etc
_ProgRetDS resw 1
_ProgRetES resw 1
_ProgRetIP resw 1
_ProgStartBP resw 1
_ProgStartSP resw 1
_ProgRetScrPage resb 1