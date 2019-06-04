SECTION .text
;WARNING: This file is deprecated. Use InitHeap/MemAlloc/MemRealloc/MemFree kernel calls.

AllocInit:
	push BP
	mov BP, SP
	sub SP, 2
	;[BP-2] - Old used size
	push BX
	push DI
	push ES
	mov AX, DS
	mov ES, AX
	mov BX, AllocBegin
	mov WORD [BP-2], 0
.countLoop:
	mov AX, [BX+AllocHeader.size]
	test AX, AX
	jz .loopEnd
	add AX, AllocHeader_size
	add BX, AX
	add [BP-2], AX
	jmp .countLoop
.loopEnd:
	xor AL, AL
	mov CX, [BP-2]
	mov DI, AllocBegin
	rep stosb
	pop ES
	pop DI
	pop BX
	mov SP, BP
	pop BP
	ret

MemAlloc: ;void *MemAlloc(int size)
	push BP
	mov BP, SP
	push BX
	mov BX, AllocBegin
	mov AX, [BP+4]
	cmp AX, MinAllocSize
	jae .seekLoop
	mov WORD [BP+4], MinAllocSize	;Entry too small, set it to minimum length
.seekLoop:
	mov CX, [BX+AllocHeader.size]
	test CX, CX
	jz .createEntry
	mov AL, [BX+AllocHeader.active]
	test AL, AL
	jnz .skipEntry	;Entry is in use
	mov AX, [BP+4]
	cmp CX, AX
	jb .skipEntry	;Not enough space
	add AX, AllocHeader_size+MinAllocSize
	cmp CX, AX
	jb .noSplit
	mov AX, [BP+4]
	mov [BX+AllocHeader.size], AX
	push BX
	add BX, AllocHeader_size
	add BX, AX
	sub CX, AX
	sub CX, AllocHeader_size
	mov [BX+AllocHeader.size], CX
	mov BYTE [BX+AllocHeader.active], 0
	pop BX
.noSplit:
	mov BYTE [BX+AllocHeader.active], 1
	add BX, AllocHeader_size
	mov AX, BX
	jmp .end
.createEntry:
	mov AX, [BP+4]
	mov BYTE [BX+AllocHeader.active], 1
	mov WORD [BX+AllocHeader.size], AX
	add BX, AllocHeader_size
	mov CX, BX
	add CX, AX
	mov AX, BX
	mov BX, CX
	xor CX, CX
	mov [BX+AllocHeader.active], CL
	mov [BX+AllocHeader.size], CX	;Make sure next entry is empty
	jmp .end
.skipEntry:
	add CX, AllocHeader_size
	add BX, CX
	jmp .seekLoop
.end:
	pop BX
	mov SP, BP
	pop BP
	ret 2

MemFree: ;void MemFree(void *addr)
	push BP
	mov BP, SP
	sub SP, 4
	;[BP-2] - Last free pointer
	;[BP-4] - Freeing
	xor AX, AX
	mov [BP-2], AX
	mov [BP-4], AL
	push BX
	mov BX, AllocBegin
	mov AX, [BP+4]
	sub AX, AllocHeader_size	;Get target header pointer
	;AX - Target block to clear
.seekLoop:
	;BX - Current entry
	;CX - Current entry length
	;DL - Current entry state
	mov CX, [BX+AllocHeader.size]
	mov DL, [BX+AllocHeader.active]
	cmp BX, AX
	jne .skipClear
	xor DL, DL
	mov [BX+AllocHeader.active], DL
.skipClear:
	test DL, DL
	jz .freeEntry
	test BYTE [BP-4], 1
	jz .continue
	mov DX, BX
	sub DX, [BP-2]
	sub DX, AllocHeader_size
	push BX
	mov BX, [BP-2]
	mov [BX+AllocHeader.size], DX
	mov BYTE [BX+AllocHeader.active], 0
	mov BYTE [BP-4], 0
	pop BX
	jmp .continue
.freeEntry:
	test BYTE [BP-4], 1
	jnz .continue
	mov [BP-2], BX
	mov BYTE [BP-4], 1
.continue:
	test CX, CX
	jz .seekEnd
	add BX, CX
	add BX, AllocHeader_size
	jmp .seekLoop
.seekEnd:
	test BYTE [BP-4], 1
	jz .skipLastClear
	xor AX, AX
	mov BX, [BP-2]
	mov [BX+AllocHeader.active], AL
	mov [BX+AllocHeader.size], AX
.skipLastClear:
	pop BX
	mov SP, BP
	pop BP
	ret 2

SECTION .dynAlloc vfollows=.bss nobits
MinAllocSize EQU 6
STRUC AllocHeader
.size resw 1
.active resb 1
ENDSTRUC

AllocBegin: