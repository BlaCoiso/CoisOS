BITS 16
SECTION .text

jmp OS_PreInit
;Jumptable for Kernel calls
jmp KernelCall

OS_PreInit:
	mov AX, 0x7C0
	mov DS, AX
	mov ES, AX
	mov SP, 0x7300
	xor BX, BX
	xor CX, CX
	xor DX, DX
	xor SI, SI
	xor DI, DI
	mov AX, 0x70
	mov FS, AX
	xor AX, AX
	mov [FS:0x19], AL
	mov [FS:0x1A], AL
	mov [FS:0x1C], AL
	call _LoadFAT
	call _LoadRootDir
	call _InitIVT
OS_Init:
	push InitStr
	call PrintString;PrintString(InitStr)
	push 0xC0
	push 0x7C0
	push 0
	call DumpMemory	;DumpMemory(0,0x7C0, 0xC0)
	call DumpRegisters
	push tmpStr
	call PrintString;PrintString(tmpStr)
	jmp Reboot
	
;System Functions

Reboot:
	xor AX, AX
	int 0x16 ;Wait for key
	xor AX, AX
	int 0x19 ;Ask BIOS to reboot
	hlt

KernelCall: ;System call wrapper for far->near calls
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
	jge .end		;Invalid call
	push DS	;BP-4
	shl BX, 1		;Each call needs a word
	mov AX, 0x7C0	;Load kernel segment
	mov DS, AX
	mov AX, [krnCallTable+BX]	;Load call pointer
	mov CX, [krnCallArgs+BX]	;Load call args
	push SI ;BP-6
	xor SI, SI
	sub SP, CX		;Allocate space for arguments
	sub SP, CX
.argLoop:
	test CX, CX
	jz .argDone
	dec CX
	mov DX, [SS:BP+SI+8]
	mov [SS:BP+SI-8], DX	;Load argument
	add SI, 2
	jmp .argLoop
.argDone:
	mov CX, [BP-4]
	mov DS, CX	;Restore data segment
	call AX
	pop SI
	mov CX, 0x7C0
	mov DS, CX	;Load data segment for call table
	mov CX, [krnCallArgs+BX]
	shl CX, 1
	add CX, 2
	pop DS
.end:
	pop BX
	mov SP, BP
	pop BP
	mov [CS:.farRet+1], CX	;Hack: Load arg size in bytes into the return instruction
.farRet: retf 2

;INCLUDES
%include "modules/string.asm"
%include "modules/disk.asm"
%include "modules/filesystem.asm"
%include "modules/debug.asm"

;DATA
SECTION .data
InitStr db 'Initializing kernel...', 0xA, 0xD, 0
tmpStr db 'The initialization code is unimplemented. Press any key to reboot.', 0xA, 0xD, 0
krnCallTable dw ReadSector, WriteSector, StringLength, PrintString
krnCallArgs dw 4, 4, 1, 1
KernelCallCount EQU 4
