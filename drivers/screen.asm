BITS 16
SECTION .text
VGA_SEG EQU 0xB800

_InitScreen:
	xor AX, AX
	mov [_ScreenPage], AL
	mov [_OffsetX], AL
	call ReadCursorPos
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
	push BX
	mov BH, [_ScreenPage]
	push BP
	int 0x10
	pop BP
	pop BX
	mov [_CursorX], DL
	mov [_CursorY], DH
	call _GetCursorPtr
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
	push BX
	mov BH, [_ScreenPage]
	push BP
	int 0x10
	pop BP
	pop BX
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
	call _GetCursorPtr
	mov AH, 2
	push BX
	mov BH, [_ScreenPage]
	push BP
	int 0x10
	pop BP
	pop BX
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
	call _GetCursorPtr
	mov AH, 2
	push BX
	mov BH, [_ScreenPage]
	push BP
	int 0x10
	pop BP
	pop BX
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

SetBackgroundColor: ;void SetBackgroundColor(int color)
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
	and AL, 0x0F
	mov AH, [BP+4]
	shl AH, 4
	and AH, 0xF0
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

_GetCursorPtr: ;void *_GetCursorPtr()
	;Assume DS is already set
	push BP
	mov BP, SP
	sub SP, 2	;[BP-2] - Temp chars
	push CX
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
	pop CX
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
	mov AX, [BP-2]
	cmp AL, ' '
	jb .special
	push BX
	mov BX, [_CursorPtr]
	mov AH, [_CursorAttribute]
	mov [FS:BX], AX
	pop BX
	inc BYTE [_CursorX]
	add WORD [_CursorPtr], 2
	jmp .end
.special:
	cmp AL, 13
	ja .end	;nothing to do
	sub AL, 8
	jb .end	;char won't be printed
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
	call _GetCursorPtr
	jmp .end
.tab:
	mov AL, [_CursorX]
	shr AL, 3	;8 space tab
	inc AL
	shl AL, 3
	mov [_CursorX], AL
	call _GetCursorPtr
	jmp .end
.lineFeed:
	inc BYTE [_CursorY]
.return:
	mov AL, [_OffsetX]
	mov BYTE [_CursorX], AL
	call _GetCursorPtr
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
	mov AL, [_OffsetX]
	mov BYTE [_CursorX], AL
	inc BYTE [_CursorY]
	call _GetCursorPtr
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
	call _GetCursorPtr
	xor DI, DI
	mov CX, [_ScreenWidth]
	mov SI, CX
	shl SI, 1
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
	call _GetCursorPtr
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

DisableCursorUpdate: ;void DisableCursorUpdate()
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

EnableCursorUpdate: ;void EnableCursorUpdate()
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

ClearScreen: ;void ClearScreen()
	push BP
	mov BP, SP
	push DS
	push ES
	push DI
	mov AX, KRN_SEG
	mov DS, AX
	xor AX, AX
	push AX
	call SetCursorPos
	xor AH, AH
	mov AL, [_ScreenPage]
	shl AX, 8
	add AX, VGA_SEG
	mov ES, AX
	mov CL, [_ScreenWidth]
	mov AL, [_ScreenHeight]
	mul CL
	mov CX, AX
	xor DI, DI
	mov AH, [_CursorAttribute]
	mov AL, ' '
	rep stosw
	pop DI
	pop ES
	pop DS
	mov SP, BP
	pop BP
	ret

PrintNewLine:
	push BP
	mov BP, SP
	push DS
	push FS
	mov AX, KRN_SEG
	mov DS, AX
	inc BYTE [_CursorY]
	mov AL, [_OffsetX]
	mov BYTE [_CursorX], AL
	call _GetCursorPtr
	xor AH, AH
	mov AL, [_ScreenPage]
	shl AX, 8	;Each screen page segment has an offset of 0x100
	add AX, VGA_SEG
	mov FS, AX
	call _CursorCheck
	pop FS
	pop DS
	mov SP, BP
	pop BP
	ret

SetCursorOffset: ;void SetCursorOffset(int offset)
	push BP
	mov BP, SP
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	call GetScreenWidth
	mov CX, [BP+4]
	cmp CX, AX
	jae .offsetOK
	xor CX, CX
.offsetOK:
	mov [_OffsetX], CL
	pop DS
	mov SP, BP
	pop BP
	ret 2

ScrollScreen: ;void ScrollScreen(int lines)
	push BP
	mov BP, SP
	push DS
	push FS
	mov AX, KRN_SEG
	mov DS, AX
	xor AH, AH
	mov AL, [_ScreenPage]
	shl AX, 8	;Each screen page segment has an offset of 0x100
	add AX, VGA_SEG
	mov FS, AX
	mov CX, [BP+4]
.loop:
	test CX, CX
	jz .end
	dec CX
	push CX
	call _ScreenScroll
	pop CX
	jmp .loop
.end:
	pop FS
	pop DS
	mov SP, BP
	pop BP
	ret 2

PrintStringL: ;void PrintStringL(char *string, int length)
	push BP
	mov BP, SP
	push SI
	mov SI, [BP+4]
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	mov BYTE [_UpdateCursor], 0
	call _GetCursorPtr
	pop DS
	mov CX, [BP+6]
.loop:
	test CX, CX
	jz .end
	dec CX
	lodsb
	test AL, AL	;Don't print after end of string
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
	pop SI
	mov SP, BP
	pop BP
	ret 4



SECTION .data
_UpdateCursor db 0xFF
_CursorAttribute db 0x0F
_ScreenWidth dw 80
_ScreenHeight dw 25
_PrintChar.specialTable dw _PrintChar.backSpace, _PrintChar.tab
dw _PrintChar.lineFeed, 0, 0, _PrintChar.return	;13

SECTION .bss
_CursorX resb 1
_CursorY resb 1
_CursorPtr resw 1
_ScreenPage resb 1
_OffsetX resb 1