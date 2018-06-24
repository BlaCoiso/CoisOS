BITS 16
SECTION .text
VGA_SEG EQU 0xB800

_InitScreen:
	call ReadCursorPos
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	call _GetCursorPtr
	pop DS
	ret

GetScreenWidth:
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AX, [_ScreenWidth]
	pop DS
	ret

GetScreenHeight:
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AX, [_ScreenHeight]
	pop DS
	ret

ReadCursorPos: ;int ReadCursorPos()
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AH, 3
	push BP
	int 0x10
	pop BP
	mov [_CursorX], DL
	mov [_CursorY], DH
	mov AX, DX
	pop DS
	mov SP, BP
	pop BP
	ret

GetCursorPos: ;int GetCursorPos()
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AL, [_CursorX]
	mov AH, [_CursorY]
	pop DS
	mov SP, BP
	pop BP
	ret

_UpdateCursorPos:
	;Assume DS is set
	mov DL, [_CursorX]
	mov DH, [_CursorY]
	mov AH, 2
	push BP
	int 0x10
	pop BP
	ret

SetCursorPos: ;void SetCursorPos(int pos)
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov DX, [BP+4]
	mov [_CursorX], DL
	mov [_CursorY], DH
	mov AH, 2
	push BP
	int 0x10
	pop BP
	pop DS
	mov SP, BP
	pop BP
	ret 2

SetCursorPosXY: ;void SetCursorPos(int x, int y)
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AX, [BP+4]	;x pos
	mov [_CursorX], AL
	mov DL, AL
	mov AX, [BP+6]	;y pos
	mov [_CursorY], AL
	mov DH, AL
	mov AH, 2
	push BP
	int 0x10
	pop BP
	pop DS
	mov SP, BP
	pop BP
	ret 4

SetCursorAttribute: ;void SetCursorAttribute(int attr)
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AX, [BP+4]
	mov [_CursorAttribute], AL
	pop DS
	mov SP, BP
	pop BP
	ret 2

GetCursorAttribute: ;int GetCursorAttribute()
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov AL, [_CursorAttribute]
	xor AH, AH
	pop DS
	mov SP, BP
	pop BP
	ret

SetTextColor: ;void SetTextColor(int color)
	push BP
	mov BP, SP
	push DS
	push FS
	push BX
	mov AX, KRN_SEG
	mov DS, AX
	xor AH, AH
	mov AL, [_ScreenPage]
	shl AX, 8	;Each screen page segment has an offset of 0x100
	add AX, VGA_SEG
	mov FS, AX
	call _GetCursorPtr
	mov BX, AX
	mov AL, [FS:BX+1]	;Load attribute at cursor
	and AL, 0xF0
	mov AH, [BP+4]
	and AH, 0xF
	or AL, AH
	mov [FS:BX+1], AL
	mov [_CursorAttribute], AL
	pop BX
	pop FS
	pop DS
	mov SP, BP
	pop BP
	ret 2

SetScreenPage: ;void SetScreenPage(int page)
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov AL, [BP+4]
	and AL, 3   ;There's only 4 display pages (0-3)
	mov [_ScreenPage], AL
	mov AH, 5
	push BP
	int 0x10
	pop BP
	call ReadCursorPos
	pop DS
	mov SP, BP
	pop BP
	ret 2

_GetCursorPtr: ;void _GetCursorPtr()
	;Assume DS is already set
	push BP
	mov BP, SP
	sub SP, 2	;[BP-2] - Temp chars
	mov AL, [_CursorX]
	xor AH, AH
	shl AX, 1
	mov [BP-2], AX
	call GetScreenWidth
	shl AX, 1
	mov CX, AX
	mov AL, [_CursorY]
	mul CL
	add AX, [BP-2]
	mov [_CursorPtr], AX
	mov SP, BP
	pop BP
	ret

_PrintChar:
	push BP
	mov BP, SP
	sub SP, 2
	mov [BP-2], AX	;Character to print
	push DS
	push FS
	push CX
	mov AX, KRN_SEG
	mov DS, AX
	xor AH, AH
	mov AL, [_ScreenPage]
	shl AX, 8	;Each screen page segment has an offset of 0x100
	add AX, VGA_SEG
	mov FS, AX
	call _GetCursorPtr
	mov AX, [BP-2]
	cmp AL, ' '
	jb .special
	push BX
	mov BX, [_CursorPtr]
	mov AH, [_CursorAttribute]
	mov [FS:BX], AX
	pop BX
	inc BYTE [_CursorX]
	jmp .end
.special:
	cmp AL, 13
	ja .end	;nothing to do
	push BX
	xor BH, BH
	mov BL, AL
	shl BX, 1
	add BX, .specialTable
	mov CX, [BX]
	pop BX
	test CX, CX
	jz .end
	jmp CX
.backSpace:
	mov AL, [_CursorX]
	test AL, AL
	jz .end
	dec BYTE [_CursorX]
	jmp .end
.tab:
	mov AL, [_CursorX]
	shr AL, 3	;8 space tab
	inc AL
	shl AL, 3
	mov [_CursorX], AL
	jmp .end
.lineFeed:
	inc BYTE [_CursorY]
.return:
	mov BYTE [_CursorX], 0
.end:
	call _CursorCheck
	pop CX
	pop FS
	pop DS
	mov SP, BP
	pop BP
	ret

_CursorCheck:
	;Assume DS and FS are set
	mov AL, [_CursorX]
	cmp AL, [_ScreenWidth]
	jb .noChange
	mov BYTE [_CursorX], 0
	inc BYTE [_CursorY]
.noChange:
	mov AL, [_ScreenHeight]
	cmp [_CursorY], AL
	jb .noScroll
	call _ScreenScroll
.noScroll:
	test BYTE [_UpdateCursor], 0xFF
	jz .noUpdate
	call _UpdateCursorPos
.noUpdate:
	ret

_ScreenScroll:
	;Assume DS and FS are set
	push BP
	mov BP, SP
	push DS
	push ES
	push DI
	push SI
	dec BYTE [_CursorY]
	xor DI, DI
	mov SI, [_ScreenWidth]
	shl SI, 1
	mov CL, [_ScreenWidth]
	mov AL, [_ScreenHeight]
	dec AL
	mul CL
	mov CX, AX
	mov AX, FS
	mov DS, AX
	mov ES, AX
	rep movsw
	mov AX, KRN_SEG
	mov DS, AX
	mov CX, [_ScreenWidth]
	mov AL, ' '
	mov AH, [_CursorAttribute]
	rep stosw
	pop SI
	pop DI
	pop ES
	pop DS
	mov SP, BP
	pop BP
	ret

PrintString: ;prints the string at DS:[BP+4] (first arg)
	push BP
	mov BP, SP
	push SI
	mov SI, [BP+4]
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov BYTE [_UpdateCursor], 0
	pop DS
.loop:
	lodsb
	test AL, AL
	jz .end
	call _PrintChar
	jmp .loop
.end:
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov BYTE [_UpdateCursor], 0xFF
	call _UpdateCursorPos
	pop DS
	mov AX, SI	;return address of end of string
	pop SI
	mov SP, BP
	pop BP
	ret 2

DisableCursorUpdate: ;void DisableCursorUpdate
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov BYTE [_UpdateCursor], 0
	pop DS
	mov SP, BP
	pop BP
	ret

EnableCursorUpdate: ;void EnableCursorUpdate
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov BYTE [_UpdateCursor], 0xFF
	call _UpdateCursorPos
	pop DS
	mov SP, BP
	pop BP
	ret

SECTION .data
_UpdateCursor db 0xFF
_CursorAttribute db 0x0F
_CursorX db 0
_CursorY db 0
_CursorPtr dw 0
_ScreenPage db 0
_ScreenWidth dw 80
_ScreenHeight dw 25
_PrintChar.specialTable dw 0, 0, 0, 0, 0, 0, 0, 0	;7
dw _PrintChar.backSpace, _PrintChar.tab, _PrintChar.lineFeed, 0	;11
dw 0, _PrintChar.return	;13