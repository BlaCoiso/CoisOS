BITS 16
;Save map file with symbol addresses when assembling
[map all kernel.map]
SECTION .text

jmp OS_PreInit
jmp KernelCall	;0x7C0:2
jmp DumpRegistersFar	;0x7C0:5

%include "consts.inc"

OS_PreInit:
	mov AX, CS
	cmp AX, KRN_SEG
	jne kernelNotExec
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
	mov [FS:SDA.sFAT], AL
	mov [FS:SDA.cfsec], AL
	mov [FS:SDA.cfrds], AL
	call _InitIVT
	call _InitScreen
	call _LoadFAT
	call _LoadRootDir
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
	
kernelNotExec:
	;TODO: Add a version file and some kind of PrintVersion thing
	;TODO: Start using some kind of version thing (vM.m.p (git-0000000))
	push NotExecStr
	call PrintString
	xor AX, AX
	not AX
	retf
	
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
	;TODO: Optimize this function to reduce overhead in kernel calls
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
%include "modules/program.asm"
%include "modules/memory.asm"

;DATA
SECTION .data
InitStr db 'Initializing kernel...', 0xA, 0
TestStr db 'Loading system executable...', 0xA, 0
TestFname db 'system.bin', 0
ReadFailStr db 'Failed to find/load system executable.', 0xA, 0
TestDoneStr db 'Returned from system console. Press any key to reboot', 0xA, 0
NotExecStr db 'Kernel cannot be executed as a program.', 0xA, 0
;Calls 0-4, 5-9
krnCallTable dw ReadSector, WriteSector, StringLength, PrintString, PrintChar
dw PrintByteHex, PrintHex, PrintNewLine, UInt2Str, Int2Str
;Calls 10-14, 15-19
dw PrintUInt, PrintInt, GetCursorPos, EmptyCall, SetCursorPos
dw SetCursorPosXY, GetCursorAttribute, SetCursorAttribute, SetTextColor, GetKey
;Calls 20-24, 25-29
dw PrintTitle, ReadString, ReadStringSafe, MemoryCopy, StringCopy
dw SetBackgroundColor, DisableCursorUpdate, EnableCursorUpdate, SetScreenPage, ClearScreen
;Calls 30-34, 35-39
dw FindFile, FindFile8_3, ReadFile, ReadFile8_3, ReadFileEntry
dw DumpMemory, GetStackTrace, ExecProgram, MemAlloc, MemFree
;Calls 40-44, 45-49
dw DrawBox, SetCursorOffset, ScrollScreen, SubStringCopy, StringConcat
dw PrintStringL, GetScreenWidth, GetScreenHeight, StringCompare, GetScreenPage
;Calls 50-54, 55-59
dw GetFileCount, ListFiles, InitHeap, MemRealloc, EmptyCall
dw FillBackgroundColor, EmptyCall, EmptyCall, EmptyCall, EmptyCall

krnCallArgs dw 4, 4, 1, 1, 1, 1, 1, 0, 2, 2	;0-9
dw 1, 1, 0, 0, 1, 2, 0, 1, 1, 0	;10-19
dw 1, 1, 2, 3, 2, 1, 0, 0, 1, 0	;20-29
dw 1, 1, 3, 3, 3, 3, 1, 4, 2, 2	;30-39
dw 5, 1, 1, 3, 2, 2, 0, 0, 2, 0	;40-49
dw 0, 3, 3, 3, 0, 1, 0, 0, 0, 0	;50-54
KernelCallCount EQU 56
