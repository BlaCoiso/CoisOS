BITS 16
SECTION .text

DumpMemory: ;void DumpMemory(int addr, int segment, int count)
	;[BP+4] - Address
	;[BP+6] - Segment
	;[BP+8] - Count
	push BP
	mov BP, SP
	push DS
	push SI
	mov AX, 0x7C0
	mov DS, AX
	push _DumpStr1
	call PrintString
	mov AX, [BP+8]
	push AX
	call PrintUInt
	push _DumpStr2
	call PrintString
	mov AX, [BP+6]
	push AX
	call PrintHex
	push _DumpStr3
	call PrintString
	mov AX, [BP+4]
	push AX
	call PrintHex
	mov AX, [BP+6]
	mov DS, AX		;Load data segment
	mov SI, [BP+4]	;Load address
	mov CX, [BP+8]	;Load count
	xor DX, DX
.dumpLoop:
	test CX, CX
	jz .end
	test DX, 15
	jnz .skipHeader
	push DX
	push CX
	call PrintNewLine
	push DS
	call PrintHex
	mov AL, ':'
	call _PrintChar
	push SI
	call PrintHex
	push _4SpaceStr
	call PrintString
	pop CX
	pop DX
.skipHeader:
	dec CX
	inc DX
	push CX
	push DX
	lodsb
	push AX
	call PrintByteHex
	push _2SpaceStr
	call PrintString
	pop DX
	pop CX
	jmp .dumpLoop
.end:
	call PrintNewLine
	pop SI
	pop DS
	mov SP, BP
	pop BP
	ret 6

DumpRegisters: ;void DumpRegisters()
	push DS	;[BP+20]
	pusha	;Save ALL registers since this must keep the system in the same state
	;[BP+4] - DI
	;[BP+6] - SI
	;[BP+8] - BP
	;[BP+10]- SP
	;[BP+12]- BX
	;[BP+14]- DX
	;[BP+16]- CX
	;[BP+18]- AX
	;[BP+22]- IP
	pushf	;[BP+2]
	push BP
	mov BP, SP
	mov AX, 0x7C0
	mov DS, AX ;Load kernel DS for strings
	call PrintNewLine
	push _RegStr
	call PrintTitle
	mov AX, [BP+18]	;Load AX
	xor BX, BX
	call .printRegister
	mov AX, [BP+12]	;Load BX
	mov BL, 1
	call .printRegister
	mov AX, [BP+16]	;Load CX
	mov BL, 2
	call .printRegister
	mov AX, [BP+14]	;Load DX
	mov BL, 3
	call .printRegister
	mov AX, [BP+6]	;Load SI
	mov BL, 13
	call .printRegister
	call PrintNewLine
	mov AX, CS		;Load CS
	mov BL, 4
	call .printRegister
	mov AX, [BP+20]	;Load DS
	mov BL, 5
	call .printRegister
	mov AX, ES		;Load ES
	mov BL, 6
	call .printRegister
	mov AX, FS		;Load FS
	mov BL, 7
	call .printRegister
	mov AX, [BP+4]	;Load DI
	mov BL, 12
	call .printRegister
	call PrintNewLine
	mov AX, SS		;Load SS
	mov BL, 8
	call .printRegister
	mov AX, [BP+10]	;Load SP
	mov BL, 10
	call .printRegister
	mov AX, [BP+8]	;Load BP
	mov BL, 11
	call .printRegister
	mov AX, [BP+22]	;Load IP
	mov BL, 9
	call .printRegister
	call PrintNewLine
	push _FlagStr
	call PrintTitle
	mov AX, [BP+2]	;Load flags
	xor BX, BX
	test AX, 1
	jz .noCarry
	call .printFlag
.noCarry:
	test AX, 4
	jz .noParity
	mov BL, 1
	call .printFlag
.noParity:
	test AX, 16
	jz .noAdjust
	mov BL, 2
	call .printFlag
.noAdjust:
	test AX, 64
	jz .noZero
	mov BL, 3
	call .printFlag
.noZero:
	test AX, 128
	jz .noSign
	mov BL, 4
	call .printFlag
.noSign:
	test AX, 256
	jz .noTrap
	mov BL, 5
	call .printFlag
.noTrap:
	test AX, 512
	jz .noInt
	mov BL, 6
	call .printFlag
.noInt:
	test AX, 1024
	jz .noDir
	mov BL, 7
	call .printFlag
.noDir:
	test AX, 2048
	jz .endFlags
	mov BL, 8
	call .printFlag
.endFlags:
	call PrintNewLine
	call PrintNewLine
	mov SP, BP
	pop BP
	popf
	popa
	pop DS
	ret
.printRegister: ;value in AX, number in BX
	xor BH, BH
	shl BX, 2 ;Each string is 4 bytes
	add BX, _RegNames
	push AX
	push BX
	call PrintString
	push _HexPrefix
	call PrintString
	call PrintHex
	push _3SpaceStr
	call PrintString
	ret
.printFlag: ;BX: flag number
	push AX
	xor BH, BH
	shl BX, 2
	add BX, _FlagNames
	push BX
	call PrintString
	pop AX
	ret

_InitIVT: ;Initializes the Interrupt Vector Table
	;TODO
	ret

_RegINTHandler: ;Register an interrupt handler: AX - Interrupt number, CX - Handler pointer
	push BP
	mov BP, SP
	push AX
	push CX
	shl AX, 2
	;TODO: Write Pointer to the address
	pop CX
	pop AX
	mov SP, BP
	pop BP
	ret


SECTION .data
_RegNames db 'AX:', 0, 'BX:', 0, 'CX:', 0, 'DX:', 0
db 'CS:', 0, 'DS:', 0, 'ES:', 0, 'FS:', 0, 'SS:', 0
db 'IP:', 0, 'SP:', 0, 'BP:', 0, 'DI:', 0, 'SI:', 0
_FlagNames db 'CF ', 0, 'PF ', 0, 'AF ', 0, 'ZF ', 0
db 'SF ', 0, 'TF ', 0, 'IF ', 0, 'DF ', 0, 'OF ', 0
_RegStr db 'CPU Registers', 0
_FlagStr db 'CPU Flags', 0
_DumpStr1 db 'Dumping ', 0
_DumpStr2 db ' bytes of memory at 0x', 0
_DumpStr3 db ':0x', 0
;Dumping 123 bytes of memory at 0x07C0:0x89AB
_4SpaceStr db ' '
_3SpaceStr db ' '
_2SpaceStr db '  ', 0