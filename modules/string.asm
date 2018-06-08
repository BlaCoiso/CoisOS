BITS 16
SECTION .text

StringLength: ;returns the length in AX of the C string at DS:[BP+4] (first arg)
	push BP
	mov BP, SP
	push DI ;saves DI into BP-2
	push CX ;saves CX into BP-4
	push ES ;saves ES into BP-6
	mov AX, DS
	mov ES, AX
	mov DI, [BP+4] ;loads first argument
	xor AX, AX
	mov CX, 0xFFFF
	repnz scasb
	mov AX, 0xFFFF
	sub AX, CX
	pop ES
	pop CX
	mov SP, BP
	pop BP
	ret 2 ;removes arg from stack (2 bytes)
	
PrintString: ;prints the string at DS:[BP+4] (first arg)
	push BP
	mov BP, SP
	push SI
	mov SI, [BP+4]
.loop:
	lodsb
	test AL, AL
	jz .end
	call _PrintChar
	jmp .loop
.end:
	mov AX, SI ;return address of end of string
	pop SI
	mov SP, BP
	pop BP
	ret 2

_PrintChar:
	push BP
	mov AH, 0xE
	int 0x10
	pop BP ;Some VBIOSes have a bug that destroys BP
	ret

_PrintByteHex: ;Prints the byte in AL in hex
	push AX
	shr AL, 4
	call _PrintHexChar
	pop AX
	call _PrintHexChar
	ret

PrintByteHex: ;void PrintByteHex(int value)
	push BP
	mov BP, SP
	mov AL, [BP+4]
	call _PrintByteHex
	mov SP, BP
	pop BP
	ret 2

_PrintHexChar:
	and AL, 0xF
	cmp AL, 10
	jb .noLetter
	add AL, 'A'-10
	call _PrintChar
	ret
.noLetter:
	add AL, '0'
	call _PrintChar
	ret

PrintHex: ;void PrintHex(int value)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	shr AX, 8
	call _PrintByteHex
	mov AX, [BP+4]
	call _PrintByteHex
	mov SP, BP
	pop BP
	ret 2

PrintNewLine:
	mov AL, 0xA
	call _PrintChar
	mov AL, 0xD
	call _PrintChar
	ret

UInt2Str: ;int UInt2Str(int value, char* buffer)
	;[BP]:	Last BP
	;[BP+2]:Return Addr
	;[BP+4]:Value
	;[BP+6]:Buffer
	push BP
	mov BP, SP
	push ES ;[BP-2]
	push DI ;[BP-4]
	push BX ;[BP-6]
	sub SP, 2;[BP-8] - temp char count
	mov AX, DS
	mov ES, AX
	mov DI, [BP+6]
	mov AX, [BP+4]
	mov BX, 10
	xor CX, CX
.chrLoop:
	xor DX, DX
	div BX
	push DX
	inc CX
	test AX, AX
	jnz .chrLoop
	mov [BP-8], CX ;Save char count
.storeLoop:
	pop AX
	dec CX
	add AL, '0'
	stosb
	test CX, CX
	jnz .storeLoop

	xor AX, AX
	stosb ;Save null byte at end
	pop AX ;Load and return char count
	pop BX
	pop DI
	pop ES
	mov SP, BP
	pop BP
	ret 4

Int2Str:
	push BP
	mov BP, SP
	push ES
	push DI
	mov AX, DS
	mov ES, AX
	mov DI, [BP+6]
	cmp WORD [BP+4], 0 ;Check if we need to print the sign
	jge .skipSign
	stosb
	mov AX, '-'
	pop DI
	mov AX, [BP+4]
	neg AX ;remove sign
	mov [BP+4], AX
.skipSign:
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	call UInt2Str
	pop DI
	pop ES
	mov SP, BP
	pop BP
	ret 4

GetCursorPos: ;int GetCursorPos()
	push BP
	mov BP, SP
	mov AH, 3
	push BP
	int 0x10
	pop BP
	mov AX, DX
	mov SP, BP
	pop BP
	ret

SetCursorPos: ;void SetCursorPos(int pos)
	push BP
	mov BP, SP
	mov DX, [BP+4]
	mov AH, 2
	push BP
	int 0x10
	pop BP
	mov SP, BP
	pop BP
	ret 2

SetCursorPosXY: ;void SetCursorPos(int x, int y)
	push BP
	mov BP, SP
	mov AX, [BP+4] ;x pos
	mov DL, AL
	mov AX, [BP+6] ;y pos
	mov DH, AL
	mov AH, 2
	push BP
	int 0x10
	pop BP
	mov SP, BP
	pop BP
	ret 4

SetCursorAttr: ;void SetCursorAttr(int attr)
	push BP
	mov BP, SP
	push BX
	mov CX, 1
	mov BL, [BP+4]
	mov AH, 9
	mov AL, ' '
	push BP
	int 0x10
	pop BP
	pop BX
	mov SP, BP
	pop BP
	ret 2

SetTextColor: ;void SetTextColor(int color)
	push BP
	mov BP, SP
	sub SP, 2	;Reserve space for local vars
	mov AH, 8
	push BP
	int 0x10
	pop BP
	and AH, 0xF0
	mov [BP-2], AX
	mov AX, [BP+4]
	and AL, 0xF
	or AL, [BP-2]
	push AX
	call SetCursorAttr
	mov SP, BP
	pop BP
	ret 2

GetCursorAttribute: ;int GetCursorAttribute()
	push BP
	mov BP, SP
	mov AH, 8
	push BP
	int 0x10
	pop BP
	shr AX, 8
	mov SP, BP
	pop BP
	ret

GetKey: ;int GetKey()
	push BP
	mov BP, SP
	xor AX, AX
	int 0x16
	mov SP, BP
	pop BP
	ret

PrintTitle: ;void PrintTitle(char* string)
	push BP
	mov BP, SP
	sub SP, 4	;Allocate space for local vars
	;[BP-2] - String length
	;[BP-4] - Separator length
	mov AX, [BP+4]	;Load string pointer into AX
	push AX
	call StringLength
	mov [BP-2], AX
	call GetCursorPos
	xor AH, AH
	add [BP-2], AX	;Add cursor X offset into length
	mov AX, [BP-2]
	inc AX
	mov CX, 80	;Each line is 80 characters
	cmp AX, CX
	ja .tooBig
	sub CX, AX
	jmp .sizeOk
.tooBig:
	xor CX, CX
.sizeOk:
	test CX, 1
	jz .skipChar
	push AX
	mov AL, '='
	call _PrintChar
	pop AX
.skipChar:
	shr CX, 1
	mov [BP-4], CX	;Save separator length
	call .printSep
	mov AL, '|'
	call _PrintChar
	mov AX, [BP+4]
	push AX
	call PrintString
	mov AL, '|'
	call _PrintChar
	mov CX, [BP-4]
	call .printSep
	mov SP, BP
	pop BP
	ret 2
.printSep:
	test CX, CX
	jz .sepEnd
	dec CX
	mov AL, '='
	call _PrintChar
	jmp .printSep
.sepEnd:
	ret

PrintInt: ;void PrintInt(int value)
	push BP
	mov BP, SP
	push DS
	mov AX, 0x7C0
	mov DS, AX
	push _IntBuf
	mov AX, [BP+4]
	push AX
	call Int2Str
	push _IntBuf
	call PrintString
	pop DS
	mov SP, BP
	pop BP
	ret 2

PrintUInt: ;void PrintUInt(int value)
	push BP
	mov BP, SP
	push DS
	mov AX, 0x7C0
	mov DS, AX
	push _IntBuf
	mov AX, [BP+4]
	push AX
	call UInt2Str
	push _IntBuf
	call PrintString
	pop DS
	mov SP, BP
	pop BP
	ret 2

ReadString: ;void ReadString(char* buffer)
	;TODO
	ret 2

ReadStringSafe: ;void ReadStringSafe(char* buffer, int maxLength)
	;TODO
	ret 2
	
DrawBox: ;void DrawBox(int x, int y, int width, int height)
	;TODO
	ret 8

SECTION .data
_SmallBox db 0xDA, 0xBF, 0xC0, 0xD9, 0xC4, 0xD3 ;UL, UR, DL, DR, HB, VB
_ThickBox db 0xC9, 0xBB, 0xC8, 0xBC, 0xBA, 0xCD
_HexPrefix db '0x',0

SECTION .bss
_IntBuf resb 7