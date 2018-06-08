BITS 16
SECTION .text

ReadSector:;void ReadSector(int sector, int count, void* buffer, int segment)
	;[BP]:	Last BP
	;[BP+2]:Return addr
	;[BP+4]:Sector
	;[BP+6]:Count
	;[BP+8]:Buffer
	;[BP+A]:Segment
	push BP
	mov BP, SP
	push ES
	push FS
	push BX
	mov AX, 0x50
	mov FS, AX
	mov AX, [BP+0xA]	;Load Buffer Segment
	test AX, AX
	jnz .noDS
	mov AX, DS
.noDS:
	mov ES, AX
	mov BX, [BP+8]		;Load Buffer Pointer
	mov CX, [BP+6]		;Load Sector Count 
	mov AX, [BP+4]		;Load Sector Offset
	mov DL, [FS:0x24]	;Load Drive Number
	test BYTE [FS:0x210], 0xFF ;Check LBA Support
	jz .noLBA
	call _ReadSectorLBA
	jmp .end
.noLBA:
	call _ReadSectorCHS
.end:
	pop BX
	pop FS
	pop ES
	mov SP, BP
	pop BP
	ret 8
	
_ReadSectorLBA:
	call _SetLBA
	push SI
.retry:
	push DS
	mov AX, 0x70
	mov DS, AX
	mov AH, 0x42
	xor SI, SI
	int 0x13
	jnc .readOK
	pop DS
	call _DiskError
	jmp .retry
.readOK:
	pop DS
	pop SI
	ret

_ReadSectorCHS:
	call _SetCHS
	mov AH, 2 ;Read sectors
.retry:
	push AX
	push DX
	int 0x13
	jnc .readOK
	call _DiskError
	pop DX
	pop AX
	jmp .retry
.readOK:
	pop DX
	pop AX
	ret

WriteSector:;void WriteSector(int sector, int count, void* buffer, int segment)
	;[BP]:	Last BP
	;[BP+2]:Return addr
	;[BP+4]:Sector
	;[BP+6]:Count
	;[BP+8]:Buffer
	;[BP+A]:Segment
	push BP
	mov BP, SP
	push ES
	push FS
	push BX
	mov AX, 0x50
	mov FS, AX
	mov AX, [BP+0xA]	;Load Buffer Segment
	mov ES, AX
	mov BX, [BP+8]		;Load Buffer Pointer
	mov CX, [BP+6]		;Load Sector Count 
	mov AX, [BP+4]		;Load Sector Offset
	mov DL, [FS:0x24]	;Load Drive Number
	test BYTE [FS:0x210], 0xFF ;Check LBA Support
	jz .noLBA
	call _WriteSectorLBA
	jmp .end
.noLBA:
	call _WriteSectorCHS
.end:
	pop BX
	pop FS
	pop ES
	mov SP, BP
	pop BP
	ret	8

_WriteSectorLBA:
	call _SetLBA
	push SI
.retry:
	push DS
	mov AX, 0x70
	mov DS, AX	;Load DS with SDA segment
	mov AH, 0x43
	xor SI, SI	;Load Disk Access Packet
	int 0x13
	jnc .writeOK
	pop DS
	call _DiskError
	jmp .retry
.writeOK:
	pop DS
	pop SI
	ret

_WriteSectorCHS:
	call _SetCHS
	mov AH, 3 ;Write sectors
.retry:
	push AX
	push DX
	int 0x13
	jnc .writeOK
	call _DiskError
	pop DX
	pop AX
	jmp .retry
.writeOK:
	pop DX
	pop AX
	ret

_SetCHS:
	push BX
	div BYTE [FS:0x18] ;Get the sector number, AH=sector number
	inc AH ;first sector is 1
	mov BX, AX ;Store it temporarily
	xor AH, AH
	div BYTE [FS:0x1A] ;Get the head number, AH=head number, AL=cylinder
	mov CH, AL ;Load cylinder number
	mov AL, CL ;Load sector count
	mov CL, BH ;Load sector start
	mov DH, AH ;Load head number
	pop BX ;Restore buffer pointer
	ret

_SetLBA:
	mov [FS:0x202], CX
	mov [FS:0x206], ES
	mov [FS:0x204], BX
	mov [FS:0x208], AX
	ret

_DiskError:
	push AX		;Save AX because it contains call args
	push DS
	mov AX, 0x7C0	;Load kernel data segment
	mov DS, AX
	xor AX, AX
	mov DL, [FS:0x24]
	clc
	int 0x13	;Reset drive
	jc .fatal	;Drive failed to reset
	push DiskErrStr1
	call PrintString
	mov AH, 1
	int 0x13	;Get Error Number
	push AX		;Save Error Number
	mov AL, AH
	xor AH, AH
	push DiskErrVal
	push AX
	call UInt2Str
	push DiskErrVal
	call PrintString
	push DiskErrStr2
	call PrintString
	pop AX		;Restore Error Number
	cmp AH, 0xD
	jb .err1
	cmp AH, 0x10
	je .err2
	cmp AH, 0x11
	je .err3
	cmp AH, 0x20
	je .err4
	cmp AH, 0x40
	je .err5
	cmp AH, 0x80
	je .err6
	cmp AH, 0xAA
	je .err7
	cmp AH, 0xCC
	je .err8
	push DErrGen
	jmp .errdone
.err1:
	dec AH
	push BX			;Save value of BX
	mov BL, AH
	xor BH, BH
	shl BL, 1
	add BX, DErrList;Get pointer to error string
	push BX
	call PrintString
	pop BX			;Restore BX
	jmp .errdone2
.err2:
	push DErr10
	jmp .errdone
.err3:
	push DErr11
	jmp .errdone
.err4:
	push DErr20
	jmp .errdone
.err5:
	push DErr40
	jmp .errdone
.err6:
	push DErr80
	jmp .errdone
.err7:
	push DErrAA
	jmp .errdone
.err8:
	push DErrCC
.errdone:
	call PrintString
.errdone2:
	dec BYTE [DiskAttempts]
	jz .fatal
	pop DS
	pop AX
	ret
.fatal:
	push DiskErrStrF
	call PrintString
	jmp Reboot

;Data
SECTION .data
DiskAttempts db 10
DiskErrStr1 db 'Disk Error (', 0
DiskErrStr2 db '): ', 0
DiskErrStrF db 'FATAL DISK ERROR, HALTING', 0
DiskErrVal times 4 db 0
DErr01 db 'Invalid Function/Parameter', 0
DErr03 db 'Read-only Disk', 0
DErr04 db 'Sector Not Found/Read Error', 0
DErr05 db 'Drive Reset Fail', 0
DErr06 db 'Disk Changed', 0
DErr08 db 'DMA Overrun', 0
DErr09 db 'Data Boundary Error', 0
DErr0A db 'Bad Sector', 0
DErr0B db 'Bad Track', 0
DErr0C db 'Invalid Media', 0
DErr10 db 'ECC Error/Corrupted Data', 0
DErr11 db 'Data ECC Corrected', 0
DErr20 db 'Controller Failure', 0
DErr40 db 'Seek Failed', 0
DErr80 db 'Disk Timeout', 0
DErrAA db 'Drive Not Ready', 0
DErrCC db 'Write Fault', 0
DErrGen db 'Unknown Disk Error', 0
DErrList dw DErr01, DErrGen, DErr03, DErr04, DErr05, DErr06, DErrGen, DErr08
dw DErr09, DErr0A, DErr0B, DErr0C
