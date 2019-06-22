BITS 16
SECTION .text

StringLength: ;returns the length in AX of the C string at DS:[BP+4] (first arg)
	push BP
	mov BP, SP
	push DI	;saves DI into BP-2
	push CX	;saves CX into BP-4
	push ES	;saves ES into BP-6
	mov AX, DS
	mov ES, AX
	mov DI, [BP+4]	;loads first argument
	xor AX, AX
	mov CX, 0xFFFF
	repnz scasb
	inc CX
	mov AX, 0xFFFF
	sub AX, CX
	pop ES
	pop CX
	pop DI
	mov SP, BP
	pop BP
	ret 2	;removes arg from stack (2 bytes)
	
PrintChar:
	push BP
	mov BP, SP
	mov AX, [BP+4]
	call _PrintChar
	mov SP, BP
	pop BP
	ret 2

_PrintByteHex:	;Prints the byte in AL in hex
	push AX
	shr AL, 4
	call _PrintHexChar
	pop AX
	call _PrintHexChar
	ret

PrintByteHex: ;void PrintByteHex(char value)
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

UInt2Str: ;int UInt2Str(int value, char *buffer)
	;[BP]:	Last BP
	;[BP+2]:Return Addr
	;[BP+4]:Value
	;[BP+6]:Buffer
	push BP
	mov BP, SP
	push ES	;[BP-2]
	push DI	;[BP-4]
	push BX	;[BP-6]
	sub SP, 2	;[BP-8] - temp char count
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
	mov [BP-8], CX	;Save char count
.storeLoop:
	pop AX
	dec CX
	add AL, '0'
	stosb
	test CX, CX
	jnz .storeLoop

	xor AX, AX
	stosb	;Save null byte at end
	pop AX	;Load and return char count
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
	cmp WORD [BP+4], 0	;Check if we need to print the sign
	jge .skipSign
	mov AX, '-'
	stosb
	inc WORD [BP+6]
	pop DI
	mov AX, [BP+4]
	neg AX	;remove sign
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

GetKey: ;int GetKey()
	push BP
	mov BP, SP
	xor AX, AX
	int 0x16
	;TODO: Add keyboard mappings for different layouts
	mov SP, BP
	pop BP
	ret

PrintTitle: ;void PrintTitle(char *string)
	push BP
	mov BP, SP
	sub SP, 4	;Allocate space for local vars
	;[BP-2] - String length
	;[BP-4] - Separator length
	mov AX, [BP+4]	;Load string pointer into AX
	push AX
	call DisableCursorUpdate
	call StringLength
	mov [BP-2], AX
	call GetCursorPos
	xor AH, AH
	add [BP-2], AX	;Add cursor X offset into length
	call GetScreenWidth
	mov CX, AX
	mov AX, [BP-2]
	add AX, 2
	cmp AX, CX
	ja .tooBig
	sub CX, AX
	jmp .sizeOk
.tooBig:
	xor CX, CX
.sizeOk:
	test CL, 1
	jz .skipChar
	push AX
	mov AL, '='
	call _PrintChar
	pop AX
.skipChar:
	shr CX, 1
	mov [BP-4], CX	;Save separator length
	call .printSep
	mov AL, '['
	call _PrintChar
	mov AX, [BP+4]
	push AX
	call PrintString
	mov AL, ']'
	call _PrintChar
	call DisableCursorUpdate
	mov CX, [BP-4]
	call .printSep
	call EnableCursorUpdate
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
	mov AX, KRN_SEG
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
	mov AX, KRN_SEG
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

ReadStringSafe: ;int ReadStringSafe(char *buffer, int maxLength)
	;[BP+6] - Max Length
	;[BP+4] - Buffer pointer
	push BP
	mov BP, SP
	sub SP, 6	;Reserve space for local variables
	;[BP-2] - Character count
	;[BP-4] - Cursor pos
	mov BYTE [BP-6], 0	;Insert Mode
	push ES
	push DI
	mov AX, DS
	mov ES, AX	;Load DS into ES
	mov DI, [BP+4]	;Load buffer pointer
	call GetCursorPos
	mov [BP-4], AX	;Store cursor position
	push DI
	call StringLength
	mov [BP-2], AX	;If the buffer isn't empty, load buffer as input
	test AX, AX
	jz .keyLoop
	add DI, AX
	call .updateBuffer
.keyLoop:
	call GetKey
	cmp AX, 0x0E08
	je .backspace
	cmp AX, 0x5300
	je .delete
	cmp AX, 0x1C0D
	je .done
	cmp AX, 0x5200
	je .toggleIns
	cmp AX, 0x4F00
	je .curEnd
	cmp AX, 0x4700
	je .curStart
	cmp AX, 0x4B00
	je .curLeft
	cmp AX, 0x4D00
	je .curRight
	cmp AX, 0x4800
	je .curUp
	cmp AX, 0x5000
	je .curDown
	cmp AL, 0x20
	jb .keyLoop	;Invalid/unsupported character
	cmp AL, 126
	ja .keyLoop
	call .addChar
	;TODO: Add something that allows an external key handler
	jmp .keyLoop
.backspace:
	cmp DI, [BP+4]
	je .keyLoop	;Already at start of buffer
	dec DI
	call .shiftBufferLeft
	jmp .keyLoop
.delete:
	cmp BYTE [DI], 0
	jz .keyLoop	;No characters after this
	call .shiftBufferLeft
	jmp .keyLoop
.curEnd:
	mov DI, [BP+4]
	add DI, [BP-2]
	call .updateCursor
	jmp .keyLoop
.curStart:
	mov DI, [BP+4]
	call .updateCursor
	jmp .keyLoop
.curLeft:
	cmp DI, [BP+4]
	je .keyLoop	;Already at start of buffer
	dec DI
	call .updateCursor
	jmp .keyLoop
.curRight:
	cmp BYTE [DI], 0
	jz .keyLoop	;No characters after this
	inc DI
	call .updateCursor
	jmp .keyLoop
.curUp:
	call GetScreenWidth
	cmp WORD [BP-2], AX
	jb .curStart
	mov CX, DI
	sub CX, [BP+4]	;Get character count before cursor
	cmp CX, AX
	jb .keyLoop
	sub DI, AX
	call .updateCursor
	jmp .keyLoop
.curDown:
	call GetScreenWidth
	cmp WORD [BP-2], AX
	jb .curEnd
	mov CX, [BP+4]
	add CX, [BP-2]
	sub CX, DI	;Get character count after cursor
	cmp CX, AX
	jb .keyLoop
	add DI, AX
	call .updateBuffer
	jmp .keyLoop
.toggleIns:
	not BYTE [BP-6]
	jmp .keyLoop
.done:
	mov AX, [BP-2]
	mov DI, [BP+4]
	add DI, AX
	call .updateCursor
	xor AX, AX
	stosb	;Add null byte at the end
	mov AX, [BP-2]
	pop DI
	pop ES
	mov SP, BP
	pop BP
	ret 4
.addChar:
	test BYTE [BP-6], 0xFF
	jnz .charInsert
.notInsert:
	mov CX, DI
	sub CX, [BP+4]	;Get current character count
	cmp CX, [BP+6]	;Check if length limit reached
	je .charEnd
	mov CX, [BP-2]
	cmp CX, [BP+6]
	je .charEnd
	push AX
	cmp BYTE [DI], 0
	je .skipShift
	call .shiftBufferRight
.skipShift:
	pop AX
	stosb
	inc WORD [BP-2]
	call .updateBuffer
.charEnd:
	ret
.charInsert:
	mov CX, [BP+4]
	add CX, [BP-2]	;Get current end pointer
	cmp DI, CX
	je .notInsert
	mov [DI], AL
	inc DI
	call .updateBuffer
	ret
.updateCursor:
	mov CX, DI
	sub CX, [BP+4]	;Get current character count
	mov AX, [BP-4]
	xor AH, AH
	add CX, AX
	push CX
	call GetScreenWidth
	pop CX
	xchg AX, CX	;AX contains char count + start offset
	cmp AX, CX
	jb .skipLineCheck
	div CL
	;AH - Cursor offset X
	;AL - Cursor offset Y
	add AL, [BP-3]	;Add Y pos
	xchg AH, AL
	push AX
	call SetCursorPos
	ret
.skipLineCheck:
	mov AH, [BP-3]
	push AX
	call SetCursorPos
	ret
.updateBuffer:
	push DI
	mov DI, [BP+4]
	add DI, [BP-2]
	mov BYTE [DI], 0	;End buffer after all characters
	pop DI
	mov AX, [BP-4]
	push AX
	call SetCursorPos
	mov AX, [BP+4]
	push AX
	call PrintString
	call GetCursorPos
	push AX
	call GetScreenHeight
	pop CX
	dec AL
	cmp CH, AL
	jb .skipScroll
	push CX
	call GetScreenWidth
	pop CX
	dec AL
	cmp CL, AL
	jb .skipScroll
	dec BYTE [BP-3]
.skipScroll:
	mov AL, ' '
	call _PrintChar
	call .updateCursor
	ret
.shiftBufferLeft:
	push DI
	dec WORD [BP-2]
.shiftLoopL:
	mov AL, [DI+1]
	mov [DI], AL
	inc DI
	test AL, AL
	jnz .shiftLoopL

	pop DI
	call .updateBuffer
	ret
.shiftBufferRight:
	mov CX, [BP-2]	;Load character count
	push DI
	xor AL, AL
	repnz scasb	;Seek to the end of the buffer
	mov AX, [BP-2]
	sub AX, CX
	mov CX, AX	;Load character count after cursor
.shiftLoopR:
	test CX, CX
	jz .shiftEnd
	mov AL, [DI-1]
	mov [DI], AL
	dec CX
	dec DI
	jmp .shiftLoopR
.shiftEnd:
	mov DI, [BP+4]
	add DI, [BP-2]
	mov BYTE [DI+1], 0
	pop DI
	ret

ReadString: ;int ReadString(char *buffer)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	push 0xFFFF
	push AX
	call ReadStringSafe
	mov SP, BP
	pop BP
	ret

_ChrToUppercase:	;Converts character in AL to uppercase
	cmp AL, 'a'
	jb .skip
	cmp AL, 'z'
	ja .skip
	sub AL, 32
.skip: ret

MemoryCopy: ;void MemoryCopy(void *dest, void *source, int length)
	push BP
	mov BP, SP
	push ES
	push DS
	pop ES	;Make sure both segments are equal
	push SI
	push DI
	mov SI, [BP+6]
	mov DI, [BP+4]
	mov CX, [BP+8]	;Load length
	test CL, 1
	jnz .noOpt
	shr CX, 1	;Optimization: Move words instead of bytes, executes faster
	rep movsw
	jmp .end
.noOpt:	rep movsb
.end:
	pop DI
	pop SI
	pop ES
	mov SP, BP
	pop BP
	ret 6

StringCopy: ;void StringCopy(char *dest, char *source)
	push BP
	mov BP, SP
	mov AX, [BP+6]	;Load source string pointer
	push AX
	call StringLength
	inc AX
	push AX
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	call MemoryCopy
	mov SP, BP
	pop BP
	ret 4

DrawBox: ;void DrawBox(int x, int y, int width, int height, int box)
	;[BP+4] - x
	;[BP+6] - y
	;[BP+8] - width
	;[BP+10]- height
	;[BP+12]- box
	push BP
	mov BP, SP
	sub SP, 4
	;[BP-2] - Old cursor pos / Screen Width
	;[BP-4] - Current Y / Screen Height
	push DS
	push BX
	mov AX, KRN_SEG
	mov DS, AX
	mov AX, [BP+12]
	cmp AL, 4
	jb .skipFix
	xor AL, AL
.skipFix:
	;TODO: Don't display sides of box if they're outside the screen
	;FIXME: Allow using last 2 lines of the screen
	push AX
	call GetScreenWidth
	sub AX, 2
	mov [BP-2], AX
	call GetScreenHeight
	sub AX, 3
	mov [BP-4], AX
	mov AX, [BP+4]
	cmp AX, [BP-2]
	jb .xPosOK
	pop AX
	jmp .end	;x pos outside horizontal bounds
.xPosOK:
	mov AX, [BP+6]
	sub AX, [BP-4]
	jb .yPosOK
	pop AX
	jmp .end	;y pos outside vertical bounds
.yPosOK:
	neg AX
	cmp [BP+10], AX
	jb .heightOK
	mov [BP+10], AX
.heightOK:
	mov AX, [BP-2]
	sub AX, [BP+4]
	cmp [BP+8], AX
	jb .widthOK
	mov [BP+8], AX
.widthOK:
	pop AX
	inc WORD [BP+10]
	mov BX, BoxChr_size
	mul BL
	add AX, _SmallBox
	mov BX, AX
	call GetCursorPos
	mov [BP-2], AX
	xor AX, AX
	mov [BP-4], AX
	call DisableCursorUpdate
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	call SetCursorPosXY
	mov AL, [BX+BoxChr.UL]
	call _PrintChar
	mov CX, [BP+8]
	test CX, CX
	jz .skipLoop1
.loop1:
	mov AL, [BX+BoxChr.HB]
	call _PrintChar
	dec CX
	test CX, CX
	jnz .loop1
.skipLoop1:
	mov AL, [BX+BoxChr.UR]
	call _PrintChar
	mov AX, [BP+10]
	cmp AL, 1
	je .skipLoop2
.loop2:
	inc BYTE [BP-4]
	mov AX, [BP-4]
	add AX, [BP+6]
	push AX
	push AX
	mov AX, [BP+4]
	push AX
	call SetCursorPosXY
	mov AL, [BX+BoxChr.VB]
	call _PrintChar
	mov AX, [BP+4]
	add AX, [BP+8]
	inc AX
	push AX
	call SetCursorPosXY
	mov AL, [BX+BoxChr.VB]
	call _PrintChar
	mov AX, [BP-4]
	cmp AX, [BP+10]
	jb .loop2
.skipLoop2:
	mov AX, [BP+10]
	add AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	call SetCursorPosXY
	mov AL, [BX+BoxChr.DL]
	call _PrintChar
	mov CX, [BP+8]
	test CX, CX
	jz .skipLoop3
.loop3:
	mov AL, [BX+BoxChr.HB]
	call _PrintChar
	dec CX
	test CX, CX
	jnz .loop3
.skipLoop3:
	mov AL, [BX+BoxChr.DR]
	call _PrintChar
	mov AX, [BP-2]
	push AX
	call SetCursorPos
	call EnableCursorUpdate
.end:
	pop BX
	pop DS
	mov SP, BP
	pop BP
	ret 10

SubStringCopy: ;void SubStringCopy(char *dest, char *source, char *length)
	push BP
	mov BP, SP
	mov AX, [BP+6]
	push AX
	call StringLength
	mov CX, [BP+8]
	cmp CX, AX
	jb .lenOk
	mov CX, AX
.lenOk:
	push CX
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	call MemoryCopy
	jmp .end
.copy:
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	call StringCopy
.end:
	mov SP, BP
	pop BP
	ret 6

StringConcat: ;void StringConcat(char *dest, char *source)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	push AX
	call StringLength
	add AX, [BP+4]
	mov CX, [BP+6]
	push CX
	push AX
	call StringCopy
	mov SP, BP
	pop BP
	ret 4

StringCompare: ;char StringCompare(char *str1, char *str2)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	cmp AX, [BP+6]
	je .equalPtr
	push AX
	call StringLength
	inc AX
	mov CX, AX
	push ES
	push SI
	push DI
	push DS
	pop ES
	mov SI, [BP+4]
	mov DI, [BP+6]
	repe cmpsb
	jne .diff
	test CX, CX
	jnz .diff
	xor AX, AX
.end:
	pop DI
	pop SI
	pop ES
	mov SP, BP
	pop BP
	ret 4
.diff:
	dec SI
	dec DI
	mov AL, [SI]
	sub AL, [DI]
	jmp .end
.equalPtr:
	xor AX, AX
	mov SP, BP
	pop BP
	ret 4

%include "drivers/screen.asm"

SECTION .data
_SmallBox db 0xDA, 0xBF, 0xC0, 0xD9, 0xC4, 0xB3 ;UL, UR, DL, DR, HB, VB
_ThickBox db 0xC9, 0xBB, 0xC8, 0xBC, 0xCD, 0xBA
_ASCIIBox db '/',  '\',  '\',  '/',  '-',  '|'
_ASCIIBox2 db '.', '.',  '`',  "'",  '-',  '|'
_HexPrefix db '0x',0

STRUC BoxChr
.UL resb 1
.UR resb 1
.DL resb 1
.DR resb 1
.HB resb 1
.VB resb 1
ENDSTRUC

SECTION .bss
_IntBuf resb 7
