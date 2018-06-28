BITS 16
;Save map file with symbol addresses when assembling
[map all kernel.map]
SECTION .text

jmp OS_PreInit
jmp KernelCall	;0x7C0:2
jmp DumpRegistersFar	;0x7C0:5
KRN_SEG EQU 0x7C0
SDA_SEG EQU 0x70
BSEC_SEG EQU 0x50
FAT_SEG EQU 0xA00
FATRD_SEG EQU 0xA40

OS_PreInit:
	mov AX, KRN_SEG
	mov DS, AX
	mov ES, AX
	mov SP, 0x7300
	xor BP, BP
	xor BX, BX
	xor CX, CX
	xor DX, DX
	xor SI, SI
	xor DI, DI
	mov AX, SDA_SEG
	mov FS, AX
	xor AX, AX
	mov [FS:0x19], AL
	mov [FS:0x1A], AL
	mov [FS:0x1C], AL
	call _InitScreen
	call _LoadFAT
	call _LoadRootDir
	call _InitIVT
OS_Init:
	push InitStr
	call PrintString	;PrintString(InitStr)
	call DumpRegisters
	push TestStr
	call PrintString	;PrintString(TestStr)
	push 0xAC0
	push 0
	push TestFname
	call ReadFile
	test AX, AX
	jz .ReadOK
	push ReadFailStr
	call PrintString
	jmp Reboot
	.ReadOK:
	push DS
	push ES
	push $	;Save current address for stack trace
	push BP
	mov BP, SP
	mov AX, 0xAC0
	mov DS, AX
	mov ES, AX
	call 0xAC0:0
	mov SP, BP
	pop BP
	add SP, 2
	pop ES
	pop DS
	push TestDoneStr
	call PrintString
	jmp Reboot
	
;System Functions

Reboot:
	xor AX, AX
	int 0x16	;Wait for key
	xor AX, AX
	int 0x19	;Ask BIOS to reboot
	hlt

KernelCall:	;System call wrapper for far->near calls
	;[BP]: Previous frame pointer
	;[BP+2]: Return address
	;[BP+4]: Return segment
	;[BP+6]: Call number
	;[BP+8]: First argument of call
	;[BP+n]: Last argument of call
	push BP
	mov BP, SP
	push BX	;BP-2
	mov CX, 2
	mov BX, [BP+6]
	cmp BX, KernelCallCount
	jge .end	;Invalid call
	push DS	;BP-4
	shl BX, 1	;Each call needs a word
	mov AX, KRN_SEG	;Load kernel segment
	mov DS, AX
	mov AX, [krnCallTable+BX]	;Load call pointer
	mov CX, [krnCallArgs+BX]	;Load call args
	push SI	;BP-6
	push DI	;BP-8
	xor SI, SI
	sub SP, CX	;Allocate space for arguments
	sub SP, CX
	mov DI, SP
.argLoop:
	test CX, CX
	jz .argDone
	dec CX
	mov DX, [SS:BP+SI+8]
	mov [SS:DI], DX	;Load argument
	add SI, 2
	add DI, 2
	jmp .argLoop
.argDone:
	mov CX, [BP-4]
	mov DS, CX	;Restore data segment
	call AX
	pop DI
	pop SI
	mov CX, KRN_SEG
	mov DS, CX	;Load data segment for call table
	mov CX, [krnCallArgs+BX]
	shl CX, 1
	add CX, 2	;First argument is call number, 2 bytes
	pop DS
.end:
	pop BX
	mov SP, BP
	pop BP
	mov [CS:.farRet+1], CX	;Hack: Load arg size in bytes into the return instruction
.farRet: retf 2

EmptyCall: ret

;INCLUDES
%include "modules/string.asm"
%include "modules/disk.asm"
%include "modules/filesystem.asm"
%include "modules/debug.asm"

;DATA
SECTION .data
InitStr db 'Initializing kernel...', 0xD, 0xA, 0
TestStr db 'Loading test program...', 0xD, 0xA, 0
TestFname db 'test.bin', 0
ReadFailStr db 'Failed to find/load test program.', 0xD, 0xA, 0
TestDoneStr db 'Returned from test program. Press any key to reboot', 0xD, 0xA, 0
krnCallTable dw ReadSector, WriteSector, StringLength, PrintString, PrintChar
dw PrintByteHex, PrintHex, PrintNewLine, UInt2Str, Int2Str

dw PrintUInt, PrintInt, GetCursorPos, EmptyCall, SetCursorPos
dw SetCursorPosXY, GetCursorAttribute, SetCursorAttribute, SetTextColor, GetKey

dw PrintTitle, ReadString, ReadStringSafe, MemoryCopy, StringCopy
dw SetBackgroundColor, DisableCursorUpdate, EnableCursorUpdate, SetScreenPage, ClearScreen

dw FindFile, FindFile8_3, ReadFile, ReadFile8_3, ReadFileEntry
dw DumpMemory

krnCallArgs dw 4, 4, 1, 1, 1, 1, 1, 0, 2, 2
dw 1, 1, 0, 0, 1, 2, 0, 1, 1, 0
dw 1, 1, 2, 3, 2, 1, 0, 0, 1, 0
dw 1, 1, 3, 3, 3, 3
KernelCallCount EQU 36
