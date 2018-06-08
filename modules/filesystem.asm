BITS 16
SECTION .text

_LoadFAT:
	push BP
	mov BP, SP
	push FS
	mov AX, 0x50
	mov FS, AX
	push 0x900	;FAT Copy Segment
	push 0		;Offset: 0
	push 2		;Read 2 Sectors
	mov AX, [FS:0x211]
	add AX, [FS:0x21A]
	push AX		;Sector Start
	call ReadSector
	pop FS
	mov SP, BP
	pop BP
	ret

_WriteFAT:
	push BP
	mov BP, SP
	push FS
	mov AX, 0x50
	mov FS, AX
	push 0x900	;FAT Copy Segment
	push 0		;Offset: 0
	push 2		;Write 2 Sectors
	mov AX, [FS:0x211]
	add AX, [FS:0x21A]
	push AX		;Sector Start
	call WriteSector
	pop FS
	mov SP, BP
	pop BP
	ret

;TODO: Somehow merge those 2 functions together, there's too much copy/paste

_LoadRootDir:
	push BP
	mov BP, SP
	push FS
	mov AX, 0x50
	mov FS, AX
	push 0x900	;FAT Copy Segment
	push 400	;Offset: 400 (Root Dir Copy)
	push 2		;Read 2 Sectors
	mov AX, [FS:0x213]
	add AX, [FS:0x21C]
	push AX		;Sector Start
	call ReadSector
	pop FS
	mov SP, BP
	pop BP
	ret

_WriteRootDir:
	push BP
	mov BP, SP
	push FS
	mov AX, 0x50
	mov FS, AX
	push 0x900	;FAT Copy Segment
	push 400	;Offset: 400 (Root Dir Copy)
	push 2		;Write 2 Sectors
	mov AX, [FS:0x213]
	add AX, [FS:0x21C]
	push AX		;Sector Start
	call WriteSector
	pop FS
	mov SP, BP
	pop BP
	ret

FindFile: ;int FindFile(char* filename)
	;Returns FFFF for not found, Root Dir Buffer Pointer if found (0x0940:PTR)
	push BP
	mov BP, SP
	push DS
	mov AX, [BP+4] ;Load filename pointer
	push AX
	call _Get8_3Name ;Get 8.3 name
	mov AX, 0x7C0
	mov DS, AX ;Load kernel segment
	push _8_3NameBuf
	call FindFile8_3
	pop DS
	mov SP, BP
	pop BP
	ret 2

FindFile8_3: ;int FindFile8_3(char* filename8_3)
	;Filename is in DS
	push BP
	mov BP, SP
	push ES
	push FS
	push DI
	push SI
	sub SP, 2		;Reserve space for local vars
	mov AX, 0x70
	mov FS, AX		;Load SDA
	mov AX, 0x940
	mov ES, AX		;Set FAT Root Dir Segment
	cmp WORD [FS:0x1C], 0
	je .skipLoad	;First sector already loaded, saves some time and I/O
	mov WORD [FS:0x1C], 0
	call _LoadRootDir
.skipLoad:
	mov SI, [BP+4]	;Load filename
	xor DI, DI
	mov [BP-2], DI
.checkLoop:
	mov DI, [BP-2]
	mov AL, [ES:DI]
	test AL, AL
	jz .fail		;End marker: no more entries after this
	cmp AL, 0xE5	;Deleted entry
	je .skip
	test BYTE [ES:DI+0xB], 	24	;Check special attributes
	jnz .skip
	mov CX, 11		;8+3
	repe cmpsb
	test CX, CX
	jnz .skip		;Filename didn't match
	mov AX, [BP-2]
	jmp .end
.skip:
	add WORD [BP-2], 32	;Each entry is 32 bytes long, skip the entry
	mov SI, [BP+4]
	cmp WORD [BP-2], 0x400
	jb .checkLoop
	add WORD [FS:0x1C], 2	;Load next 2 sectors of the root dir
	call _LoadRootDir
	mov WORD [BP-2], 0	;Reset entry pointer
	jmp .checkLoop
.fail:
	mov AX, 0xFFFF	;File not found
.end:
	add SP, 2		;Clean local vars
	pop SI
	pop DI
	pop FS
	pop ES
	mov SP, BP
	pop BP
	ret 2

_Get8_3Name: ;[BP+4] = Filename pointer
	push BP
	mov BP, SP
	push SI ;Save registers
	push DI
	push ES
	sub SP, 2 ;Reserve space for local vars
	mov BYTE [BP-8], 0	;[BP-8] = Before Dot Count
	mov BYTE [BP-9], 0	;[BP-9] = After Dot Count
	mov AX, 0x7C0
	mov ES, AX
	mov DI, _8_3NameBuf
	mov SI, [BP+4]
.charLoop:
	lodsb
	call _ChrToUppercase
	cmp AL, '.'
	je .dot
	cmp AL, 'A'
	jb .notLetter
	cmp AL, 'Z'
	ja .notLetter
	;AL is a letter, write it
	jmp .writeChr
.notLetter:
	cmp AL, '0'
	jb .notDigit
	cmp AL, '9'
	ja .notDigit
	;AL is a digit, write it
	jmp .writeChr
.notDigit: ;Check for special characters
	test AL, AL
	jz .end
	cmp AL, ' '
	je .space
	cmp AL, '#'
	je .writeChr
	cmp AL, '$'
	je .writeChr
	cmp AL, '%'
	je .writeChr
	cmp AL, '&'
	je .writeChr
	cmp AL, "'"
	je .writeChr
	cmp AL, '('
	je .writeChr
	cmp AL, ')'
	je .writeChr
	cmp AL, '-'
	je .writeChr
	cmp AL, '@'
	je .writeChr
	cmp AL, '^'
	je .writeChr
	cmp AL, '_'
	je .writeChr
	cmp AL, '`'
	je .writeChr
	cmp AL, '{'
	je .writeChr
	cmp AL, '}'
	je .writeChr
	cmp AL, '~'
	je .writeChr
	;If all checks failed, the character is invalid
	jmp .charLoop
.space:
	cmp BYTE [BP-8], 0
	je .charLoop ;Don't allow space on beginning
	jmp .writeChr
.dot:
	cmp BYTE [BP-8], 0
	je .charLoop ;Dots aren't allowed in the first character
	cmp BYTE [BP-9], 0
	jne .charLoop ;Dots aren't allowed in the extension
.padLoop:
	cmp BYTE [BP-8], 8
	je .charLoop
	mov AL, ' '
	stosb
	inc BYTE [BP-8]
	jmp .padLoop
.writeChr:
	cmp BYTE [BP-8], 8
	jb .writeBefore
	cmp BYTE [BP-9], 0
	je .charLoop ;Ignore everything until a dot
	cmp BYTE [BP-9], 3
	jb .writeAfter
	jmp .end ;No more space available, ignore remaining characters
.writeBefore:
	stosb
	inc BYTE [BP-8]
	jmp .charLoop
.writeAfter:
	stosb
	inc BYTE [BP-9]
	jmp .charLoop
.end:
	cmp BYTE [BP-8], 8
	je .padDot
	mov AL, ' '
	stosb
	inc BYTE [BP-8]
	jmp .end
.padDot:
	cmp BYTE [BP-9], 3
	je .padEnd
	mov AL, ' '
	stosb
	inc BYTE [BP-9]
	jmp .padDot
.padEnd:
	xor AL, AL
	stosb ;End with null byte
	add SP, 2 ;Clean up local vars
	pop ES
	pop DI
	pop SI
	mov SP, BP
	pop BP
	ret 2

_ChrToUppercase: ;Converts character in AL to uppercase
	cmp AL, 'a'
	jb .skip
	cmp AL, 'z'
	ja .skip
	sub AL, 32
.skip: ret

ReadFile: ;int ReadFile(char* filename, void* buffer, int segment)
	;TODO
	ret 6

ReadFile8_3: ;int ReadFile8_3(char* filename8_3, void* buffer, int segment)
	;TODO
	ret 6
ReadFileEntry: ;int ReadFileEntry(int* rootDirEntry, void* buffer, int segment)
	;TODO
	ret 6

SECTION .bss
_8_3NameBuf resb 12
