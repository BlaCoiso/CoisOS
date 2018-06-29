BITS 16
SECTION .text

DumpMemory: ;void DumpMemory(int addr, int segment, int count)
	;[BP+4] - Address
	;[BP+6] - Segment
	;[BP+8] - Count, if MSB set then ignore header
	push BP
	mov BP, SP
	push DS
	push SI
	mov AX, KRN_SEG
	mov DS, AX
	mov AX, [BP+8]
	test AH, 128	;Check ignore header bit
	jnz .skipHeader
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
.skipHeader:
	mov AX, [BP+6]
	mov DS, AX	;Load data segment
	mov SI, [BP+4]	;Load address
	mov CX, [BP+8]	;Load count
	and CH, 127	;Clear ignore header bit
	xor DX, DX	;Printed count
.dumpLoop:
	test CX, CX
	jz .end
	test DX, 15
	jnz .skipAddr
	push DX
	push CX
	call PrintNewLine
	push DS
	call PrintHex
	mov AL, ':'
	call _PrintChar
	push SI
	call PrintHex
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	push _4SpaceStr
	call PrintString
	pop DS
	pop CX
	pop DX
.skipAddr:
	dec CX
	inc DX
	push CX
	push DX
	lodsb
	push AX
	call PrintByteHex
	push DS
	mov AX, KRN_SEG
	mov DS, AX
	push _2SpaceStr
	call PrintString
	pop DS
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
	push BP
	mov BP, SP
	push AX
	lea AX, [BP+4]
	push AX	;SP before call
	mov AX, [BP+2]
	push AX	;IP before call
	push CS
	call _DumpRegisters
	mov AX, [BP-2]
	mov SP, BP
	pop BP
	ret

DumpRegistersFar: ;void DumpRegistersFar()
	push BP
	mov BP, SP
	push AX
	lea AX, [BP+6]
	push AX	;SP before call
	mov AX, [BP+2]
	push AX	;IP before call
	mov AX, [BP+4]
	push AX	;CS before call
	call _DumpRegisters
	mov AX, [BP-2]
	mov SP, BP
	pop BP
	retf

_DumpRegisters: ;void _DumpRegisters(CS,IP,SP,AX,BP)
	;[BP+22] - Internal caller address
	push DS	;[BP+20]
	pusha	;Save ALL registers since this must keep the system in the same state
	;[BP+4] - DI
	;[BP+6] - SI
	;[BP+32]- BP
	;[BP+28]- SP
	;[BP+12]- BX
	;[BP+14]- DX
	;[BP+16]- CX
	;[BP+30]- AX
	;[BP+26]- IP
	;[BP+24]- CS
	pushf	;[BP+2]
	push BP
	mov BP, SP
	mov AX, KRN_SEG
	mov DS, AX	;Load kernel DS for strings
	call PrintNewLine
	push _RegStr
	call PrintTitle
	mov AX, [BP+30]	;Load AX
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
	mov AX, [BP+24]	;Load CS
	mov BL, 4
	call .printRegister
	mov AX, [BP+20]	;Load DS
	mov BL, 5
	call .printRegister
	mov AX, ES	;Load ES
	mov BL, 6
	call .printRegister
	mov AX, FS	;Load FS
	mov BL, 7
	call .printRegister
	mov AX, [BP+4]	;Load DI
	mov BL, 12
	call .printRegister
	call PrintNewLine
	mov AX, SS	;Load SS
	mov BL, 8
	call .printRegister
	mov AX, [BP+28]	;Load SP
	mov BL, 10
	call .printRegister
	mov AX, [BP+32]	;Load BP
	mov BL, 11
	call .printRegister
	mov AX, [BP+26]	;Load IP
	mov BL, 9
	call .printRegister
	call PrintNewLine
	push _FlagStr
	call PrintString
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
	mov AL, ']'
	call _PrintChar
	call PrintNewLine
	mov SP, BP
	pop BP
	popf
	popa
	pop DS
	ret 10
.printRegister: ;value in AX, number in BX
	xor BH, BH
	shl BX, 2	;Each string is 4 bytes
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
	mov AX, 3
	mov CX, Int3Handler
	call _RegINTHandler
	mov AX, 1
	call _RegINTHandler
	ret

_RegINTHandler: ;Register an interrupt handler: AX - Interrupt number, CX - Handler pointer
	push BP
	mov BP, SP
	push AX
	push CX
	push BX
	push ES
	shl AX, 2	;Each interrupt is 4 bytes
	xor BX, BX
	mov ES, BX
	mov BX, AX
	mov [ES:BX], CX
	mov WORD [ES:BX+2], KRN_SEG
	pop ES
	pop BX
	pop CX
	pop AX
	mov SP, BP
	pop BP
	ret

GetStackTrace: ;void GetStackTrace(int *FrameBase)
	push BP
	mov BP, SP
	push BX
	mov BX, [BP+4]	;Load frame pointer
.loop:
	test BX, BX
	jz .end
	cmp BX, [SS:BX]
	je .end
	mov AX, [SS:BX+2]	;Load return address of frame
	push AX
	call PrintHex
	mov BX, [SS:BX]
	push '<'
	call PrintChar
	jmp .loop
.end:
	pop BX
	mov SP, BP
	pop BP
	ret 2

%include "modules/interrupts.asm"

SECTION .data
_RegNames db 'AX:', 0, 'BX:', 0, 'CX:', 0, 'DX:', 0
db 'CS:', 0, 'DS:', 0, 'ES:', 0, 'FS:', 0, 'SS:', 0
db 'IP:', 0, 'SP:', 0, 'BP:', 0, 'DI:', 0, 'SI:', 0
_FlagNames db 'CF ', 0, 'PF ', 0, 'AF ', 0, 'ZF ', 0
db 'SF ', 0, 'TF ', 0, 'IF ', 0, 'DF ', 0, 'OF ', 0
_RegStr db 'CPU Registers', 0
_FlagStr db 'CPU Flags: [ ', 0
_DumpStr1 db 'Dumping ', 0
_DumpStr2 db ' bytes of memory at 0x', 0
_DumpStr3 db ':0x', 0
;Dumping 123 bytes of memory at 0x07C0:0x89AB
_4SpaceStr db ' '
_3SpaceStr db ' '
_2SpaceStr db '  ', 0