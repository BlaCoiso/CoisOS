BITS 16
SECTION .text

_LoadFAT:
	push BP
	mov BP, SP
	push FS
	mov AX, BSEC_SEG
	mov FS, AX
	push FAT_SEG	;FAT Copy Segment
	push 0	;Offset: 0
	push 2	;Read 2 Sectors
	mov AX, [FS:SDA_OFFS+SDA.FATo]
	add AX, [FS:SDA_OFFS+SDA.cfsec]
	push AX	;Sector Start
	call ReadSector
	pop FS
	mov SP, BP
	pop BP
	ret

_WriteFAT:
	push BP
	mov BP, SP
	push FS
	mov AX, BSEC_SEG
	mov FS, AX
	push FAT_SEG	;FAT Copy Segment
	push 0	;Offset: 0
	push 2	;Write 2 Sectors
	mov AX, [FS:SDA_OFFS+SDA.FATo]
	add AX, [FS:SDA_OFFS+SDA.cfsec]
	push AX	;Sector Start
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
	mov AX, BSEC_SEG
	mov FS, AX
	push FAT_SEG	;FAT Copy Segment
	push RD_OFFS	;Offset: 0x400 (Root Dir Copy)
	push 2	;Read 2 Sectors
	mov AX, [FS:SDA_OFFS+SDA.FATdo]
	add AX, [FS:SDA_OFFS+SDA.cfrds]
	push AX	;Sector Start
	call ReadSector
	pop FS
	mov SP, BP
	pop BP
	ret

_WriteRootDir:
	push BP
	mov BP, SP
	push FS
	mov AX, BSEC_SEG
	mov FS, AX
	push FAT_SEG	;FAT Copy Segment
	push RD_OFFS	;Offset: 0x400 (Root Dir Copy)
	push 2	;Write 2 Sectors
	mov AX, [FS:SDA_OFFS+SDA.FATdo]
	add AX, [FS:SDA_OFFS+SDA.cfrds]
	push AX	;Sector Start
	call WriteSector
	pop FS
	mov SP, BP
	pop BP
	ret

FindFile: ;int FindFile(char* filename)
	;Returns FFFF for not found, Root Dir Buffer Pointer if found (FATRD_SEG:PTR)
	push BP
	mov BP, SP
	push DS
	mov AX, [BP+4]	;Load filename pointer
	push AX
	call _Get8_3Name	;Get 8.3 name
	mov AX, KRN_SEG
	mov DS, AX	;Load kernel segment
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
	sub SP, 2	;Reserve space for local vars
	;[BP-2] - Current entry
	push ES
	push FS
	push DI
	push SI
	mov AX, SDA_SEG
	mov FS, AX	;Load SDA
	mov AX, FATRD_SEG
	mov ES, AX	;Set FAT Root Dir Segment
	cmp WORD [FS:SDA.cfrds], 0
	je .skipLoad	;First sector already loaded, saves some time and I/O
	mov WORD [FS:SDA.cfrds], 0
	call _LoadRootDir
.skipLoad:
	mov SI, [BP+4]	;Load filename
	xor DI, DI
	mov [BP-2], DI
.checkLoop:
	mov DI, [BP-2]
	mov AL, [ES:DI]
	test AL, AL
	jz .fail	;End marker: no more entries after this
	cmp AL, 0xE5	;Deleted entry
	je .skip
	test BYTE [ES:DI+FSEnt.attr], 24	;Check special attributes
	jnz .skip
	mov CX, 11	;8+3
	repe cmpsb
	test CX, CX
	jnz .skip	;Filename didn't match
	mov AX, [BP-2]
	jmp .end
.skip:
	add WORD [BP-2], 32	;Each entry is 32 bytes long, skip the entry
	mov SI, [BP+4]
	cmp WORD [BP-2], 0x400
	jb .checkLoop
	add WORD [FS:SDA.cfrds], 2	;Load next 2 sectors of the root dir
	call _LoadRootDir
	mov WORD [BP-2], 0	;Reset entry pointer
	jmp .checkLoop
.fail:
	mov AX, 0xFFFF	;File not found
.end:
	pop SI
	pop DI
	pop FS
	pop ES
	mov SP, BP
	pop BP
	ret 2

_Get8_3Name:	;[BP+4] = Filename pointer
	push BP
	mov BP, SP
	sub SP, 3	;Reserve space for local vars
	mov BYTE [BP-2], 0	;[BP-2] = Before Dot Count
	mov BYTE [BP-3], 0	;[BP-3] = After Dot Count
	mov BYTE [BP-4], 0	;[BP-4] = Dot Ready
	push SI	;Save registers
	push DI
	push ES
	mov AX, KRN_SEG
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
.notDigit:	;Check for special characters
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
	cmp BYTE [BP-2], 0
	je .charLoop	;Don't allow space on beginning
	jmp .writeChr
.dot:
	cmp BYTE [BP-2], 0
	je .charLoop	;Dots aren't allowed in the first character
	cmp BYTE [BP-3], 0
	jne .charLoop	;Dots aren't allowed in the extension
	mov BYTE [BP-4], 0xFF
.padLoop:
	cmp BYTE [BP-2], 8
	je .charLoop
	mov AL, ' '
	stosb
	inc BYTE [BP-2]
	jmp .padLoop
.writeChr:
	cmp BYTE [BP-2], 8
	jb .writeBefore
	test BYTE [BP-4], 0xFF
	jz .charLoop	;Ignore everything until a dot
	cmp BYTE [BP-3], 3
	jb .writeAfter
	jmp .padEnd	;No more space available, ignore remaining characters
.writeBefore:
	stosb
	inc BYTE [BP-2]
	jmp .charLoop
.writeAfter:
	stosb
	inc BYTE [BP-3]
	jmp .charLoop
.end:
	cmp BYTE [BP-2], 8
	je .padDot
	mov AL, ' '
	stosb
	inc BYTE [BP-2]
	jmp .end
.padDot:
	cmp BYTE [BP-3], 3
	je .padEnd
	mov AL, ' '
	stosb
	inc BYTE [BP-3]
	jmp .padDot
.padEnd:
	xor AL, AL
	stosb	;End with null byte
	pop ES
	pop DI
	pop SI
	mov SP, BP
	pop BP
	ret 2

_GetNextCluster: ;int _GetNextCluster(int cluster)
	push BP
	mov BP, SP
	push ES
	push BX
	push FS
	mov AX, FAT_SEG
	mov ES, AX
	mov AX, SDA_SEG
	mov FS, AX
	mov BX, [BP+4]
	shl BX, 1	;Each cluster is 2 bytes
	mov AX, BX
	and BX, 1023
	shr AX, 9
	and AX, 0xFFFE
	cmp AX, [FS:SDA.cfsec]
	je .skipLoad
	mov [FS:SDA.cfsec], AX
	call _LoadFAT
.skipLoad:
	mov AX, [ES:BX]
	pop FS
	pop BX
	pop ES
	mov SP, BP
	pop BP
	ret 2

_LoadCluster:	;int _LoadCluster(int cluster, void* buffer, int segment)
	push BP
	mov BP, SP
	sub SP, 2	;[BP-2] - Sectors per cluster
	push FS
	mov AX, [BP+8]
	push AX
	mov AX, [BP+6]
	push AX
	mov AX, BSEC_SEG
	mov FS, AX	;Load System segment
	mov AL, [FS:BSEC.spc]	;Load sectors per cluster
	xor AH, AH
	mov [BP-2], AX
	push AX
	mov AX, [BP+4]	;Load cluster number
	sub AX, 2	;First 2 clusters aren't "real"
	mov CX, [BP-2]
	mul CL	;Get cluster data offset
	add AX, [FS:SDA_OFFS+SDA.fsfdo]	;Load File Data offset
	push AX
	call ReadSector
	mov AX, [BP-2]
	shl AX, 9	;Multiply by 512 (sector size)
	add AX, [BP+6]
	pop FS
	mov SP, BP
	pop BP
	ret 6

ReadFile: ;bool ReadFile(char* filename, void* buffer, int segment)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	push AX
	call FindFile
	cmp AX, 0xFFFF
	je .noFile
	mov CX, [BP+8]
	push CX
	mov CX, [BP+6]
	push CX
	push AX
	call ReadFileEntry
.noFile:
	mov SP, BP
	pop BP
	ret 6

ReadFile8_3: ;bool ReadFile8_3(char* filename8_3, void* buffer, int segment)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	push AX
	call FindFile8_3
	cmp AX, 0xFFFF
	je .noFile
	mov CX, [BP+8]
	push CX
	mov CX, [BP+6]
	push CX
	push AX
	call ReadFileEntry
.noFile:
	mov SP, BP
	pop BP
	ret 6

ReadFileEntry: ;void ReadFileEntry(int* rootDirEntry, void* buffer, int segment)
	push BP
	mov BP, SP
	sub SP, 2	;Local variables
	;[BP-2] - Previous cluster
	push ES
	push SI
	mov AX, FAT_SEG
	mov ES, AX	;Load FAT Data segment
	mov SI, [BP+4]
	add SI, 0x400	;Load file entry
	mov AX, [ES:SI+FSEnt.cluster]	;Load cluster number
	mov [BP-2], AX
.loadLoop:
	cmp AX, 0xFFF0
	jae .loadEnd
	mov AX, [BP+8]
	push AX
	mov AX, [BP+6]
	push AX
	mov AX, [BP-2]
	push AX
	push AX
	call _GetNextCluster
	mov [BP-2], AX	;Save next cluster
	call _LoadCluster
	mov [BP+6], AX	;Save new buffer offset
	mov AX, [BP-2]
	jmp .loadLoop
.loadEnd:
	xor AX, AX
	pop SI
	pop ES
	mov SP, BP
	pop BP
	ret 6

_From8_3Name: ;void _From8_3Name(char *name8_3)
	push BP
	mov BP, SP
	sub SP, 1
	;[BP-2] - Spaces
	push SI
	push DI
	push ES
	mov DI, _FileNameBuf
	mov SI, [BP+4]
	mov AX, KRN_SEG
	mov ES, AX
	mov CX, 11
.loop:
	test CX, CX
	jz .end
	dec CX
	lodsb
	cmp AL, ' '
	jne .skipSpace
	inc BYTE [BP-2]
	jmp .loop
.skipSpace:
	cmp BYTE [BP-2], 0
	jz .skipCheck
	push AX
	mov AX, SI
	sub AX, [BP+4]	;Get current char pos
	cmp AL, 8
	pop AX
	ja .skipCheck
	push CX
	push AX
	mov CL, [BP-2]
	mov AL, ' '
	rep stosb	;Include spaces in the name
	pop AX
	pop CX
	mov BYTE [BP-2], 0
.skipCheck:
	push AX
	mov AX, SI
	sub AX, [BP+4]
	cmp AL, 9
	jne .skipDot
	mov AL, '.'
	stosb
.skipDot:
	pop AX
	stosb
	jmp .loop
.end:
	xor AL, AL
	stosb	;Add null byte at the end
	pop ES
	pop DI
	pop SI
	mov SP, BP
	pop BP
	ret 2

SECTION .bss
_8_3NameBuf resb 12
_FileNameBuf resb 13

STRUC FSEnt
.name resb 8
.ext resb 3
.attr resb 1
resb 1
.crms resb 1
.crtime resw 1
.crdate resw 1
.ladate resw 1
resw 1
.lwtime resw 1
.lwdate resw 1
.cluster resw 1
.size resd 1
ENDSTRUC