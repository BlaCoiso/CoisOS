BITS 16
SECTION .text

InitHeap: ;void InitHeap(void *heapStart, void *heapEnd, int blockSize)
	push BP
	mov BP, SP
	push BX
	mov BX, [BP+4]
	mov AX, [BP+6]
	sub AX, BX
	mov [BX+HeapHeader.size], AX
	mov AX, [BP+8]
	cmp AX, 64
	mov AH, 6
	mov CL, 64
	jb .size32
	mov AL, CL	;Block size = 64 bytes
	jmp .setSize
.size32:
	shr CL, 1
	dec AH
	test AL, CL
	jz .size16
	and AL, CL	;Block size = 32 bytes
	jmp .setSize
.size16:
	shr CL, 1
	dec AH
	test AL, CL
	jz .size8
	and AL, CL ;Block size = 16 bytes
	jmp .setSize
.size8:
	mov AL, 8	;Block size = 8 bytes
	dec AH
.setSize:
	mov [BX+HeapHeader.blockSize], AL
	mov [BX+HeapHeader.blockShift], AH
	mov CL, AH
	mov CH, AL
	dec CH	;CH contains bit mask
	mov AX, BX
	add AX, HeapHeader_size + 128   ;Each block table must have at least 128 bytes
	test AL, CH
	jz .addrOK	;Address is already aligned
	shr AX, CL
	inc AX
	shl AX, CL	;Align address so bit mask for allocated addresses is always clear
.addrOK:
	mov [BX+HeapHeader.allocStart], AX
	add BX, HeapHeader_size	;Seek to block table
	push AX
	neg AX
	add AX, [BP+6]
	shr AX, CL
	and AX, ~3	;Make sure unalloc & 3 = 0 so DX = 0 checks pass
	;TODO: Add fake blocks at the end and add special checks for DX = 1
	mov [BX-HeapHeader_size+HeapHeader.unalloc], AX
	pop AX
	sub AX, BX	;Get table length
	push AX
	mov CX, AX
	push ES
	push DI
	mov AX, DS
	mov ES, AX
	xor AX, AX
	mov DI, BX
	rep stosb   ;Fill table with zeros
	pop DI
	pop ES
	pop AX
	sub AX, BlockHeader_size
	shl AX, 2   ;Each byte in the table stores 4 blocks
	cmp AX, [BX-HeapHeader_size+HeapHeader.unalloc]
	jbe .allocOK
	mov AX, [BX-HeapHeader_size+HeapHeader.unalloc]
.allocOK:
	mov [BX+BlockHeader.size], AX
	sub [BX-HeapHeader_size+HeapHeader.unalloc], AX
	xor AX, AX
	mov [BX+BlockHeader.parent], AX
	mov [BX+BlockHeader.next], AX
	push SI
	push DI
	mov AX, [BP+4]
	push AX
	call _InitMemRegs
	call _AllocBlockTable
	pop DI
	pop SI
	pop BX
	mov SP, BP
	pop BP
	ret 6

_InitMemRegs: ;void _InitMemRegs(void *heapStart)
	push BP
	mov BP, SP
	mov DI, [BP+4]
	call _ResetMemRegs
	mov SP, BP
	pop BP
	ret 2

_ResetMemRegs:
	xor CL, CL
	mov BX, DI
	add BX, HeapHeader_size
	mov SI, BlockHeader_size
	mov DX, [BX+BlockHeader.size]
	ret

_SeekHeapBlock:
	sub DX, 4
	xor CH, CH
	add DX, CX
	xor CL, CL
	test DX, DX
	jz .tableEnd
	inc SI
	xor AX, AX
	ret
.tableEnd:
	mov AX, [BX+BlockHeader.next]
	test AX, AX
	jz .nextFail
	mov SI, BlockHeader_size
	mov BX, AX
	mov DX, [BX+BlockHeader.size]
	call _AllocBlockTable
	xor AX, AX
	ret
.nextFail:
	mov AX, 0xFFFF
	ret

_SeekBlocks: ;_SeekBlocks(count@AX)
	test AX, AX
	jz .end
	xor CH, CH
	test AX, ~3
	jz .count4
	test CL, CL
	jz .noAlign
.addrAlign:
	sub AX, 4
	add AX, CX
	push AX
	call _SeekHeapBlock
	pop AX
.noAlign:
	test AX, ~3
	jz .loopEnd
	push AX
	call _SeekHeapBlock
	pop AX
	sub AX, 4
	jmp .noAlign

.count4:
	mov AH, AL
	add AH, CL
	test AH, ~3
	mov AH, CH
	jz .loopEnd
	jmp .addrAlign

.loopEnd:
	add CL, AL
	sub DX, AX
.end:
	ret

_GetChainLength:
	push BP
	mov BP, SP
	sub SP, 2
	;[BP-2] - Length
	push BX
	push SI
	push DX
	push CX
	mov WORD [BP-2], 0
	mov AL, [BX+SI]
	shr AL, CL
	test AL, MASK_SET
	jz .end
.lengthLoop:
	test AL, MASK_LINK
	jz .endChain
	inc WORD [BP-2]
	cmp CL, 3
	je .nextBlock
	inc CL
	dec DX
	shr AL, 1
	jmp .lengthLoop
.nextBlock:
	call _SeekHeapBlock
	not AX
	test AX, AX
	jz .fail
	mov AL, [BX+SI]
	jmp .lengthLoop

.endChain:
	test AL, MASK_SET
	jz .invalidFix
	inc WORD [BP-2]
.end:
	pop CX
	pop DX
	pop SI
	pop BX
	mov AX, [BP-2]
	mov SP, BP
	pop BP
	ret
.invalidFix:
	mov AL, [BX+SI]
	mov DH, MASK_UNLINK
	rol DH, CL
	and AL, DH
	mov [BX+SI], AL
	jmp .end
.fail:
	mov WORD [BP-2], 0xFFFF
	jmp .end

_SetChainLength: ;_SetChainLength(length@AX)
	push BP
	mov BP, SP
	sub SP, 6
	;[BP-2] - Target length
	;[BP-4] - Current length
	;[BP-6] - Count
	mov [BP-2], AX
	call _GetChainLength
	mov [BP-4], AX
	cmp AX, [BP-2]
	je .endOK	;Target length is same as current
	cmp WORD [BP-2], 0
	je .clear	;Target length is 0, clear chain
	cmp [BP-2], AX
	ja .enlarge	;Target length is greater than current, enlarge chain
	push BX
	push SI
	push DX
	push CX
	mov AX, [BP-2]
	dec AX
	call _SeekBlocks
	mov AL, [BX+SI]
	mov CH, MASK_UNLINK
	rol CH, CL
	and AL, CH
	mov [BX+SI], AL	;Unlink last block
	cmp CL, 3
	je .nextBlockL
	inc CL
	dec DX
.clearL:
	call _ClearChain
	pop CX
	pop DX
	pop SI
	pop BX
	jmp .endOK

.nextBlockL:
	call _SeekHeapBlock
	jmp .clearL

.enlarge:
	push BX
	push SI
	push DX
	push CX
	call _SeekEndChain
	push BX
	push SI
	push DX
	push CX
	cmp CL, 3
	je .nextBlockGS
	inc CL
	dec DX
.seekEndOK:
	mov AX, [BP-2]
	sub AX, [BP-4]
	;TODO: Check if it fails when only 1 block is free after end
	mov [BP-6], AX
	mov AL, [BX+SI]
	shr AL, CL
.checkLoop:
	cmp WORD [BP-6], 0
	jz .checkOK
	dec WORD [BP-6]
	test AL, MASK_SET
	jnz .checkFail
	cmp CL, 3
	je .nextBlockGCL
	inc CL
	dec DX
	shr AL, 1
	jmp .checkLoop

.nextBlockGS:
	call _SeekHeapBlock
	jmp .seekEndOK

.checkFail:
	add SP, 8
	pop CX
	pop DX
	pop SI
	pop BX
	jmp .fail

.nextBlockGCL:
	call _SeekHeapBlock
	not AX
	test AX, AX
	jz .checkFail
	mov AL, [BX+SI]
	jmp .checkLoop

.checkOK:
	pop CX
	pop DX
	pop SI
	pop BX
	mov AX, [BP-2]
	sub AX, [BP-4]
	dec AX
	mov [BP-6], AX	;count = targetLength - currentLength - 1
	mov AL, [BX+SI]
	mov CH, MASK_SET_LINK
	shl CH, CL
.linkLoop:
	cmp WORD [BP-6], 0
	jz .linkEnd
	dec WORD [BP-6]
	or AL, CH
	cmp CL, 3
	je .nextBlockGLL
	inc CL
	dec DX
	shl CH, 1
	jmp .linkLoop

.nextBlockGLL:
	mov [BX+SI], AL
	call _SeekHeapBlock
	mov AL, [BX+SI]
	mov CH, MASK_SET_LINK
	jmp .linkLoop

.linkEnd:
	mov CH, MASK_SET
	shl CH, CL
	or AL, CH
	mov [BX+SI], AL
	pop CX
	pop DX
	pop SI
	pop BX
	jmp .endOK

.clear:
	call _ClearChain
.endOK:
	xor AX, AX
.end:
	mov SP, BP
	pop BP
	ret
.fail:
	mov AX, 0xFFFF
	jmp .end

_ClearChain:
	push BP
	mov BP, SP
	sub SP, 2
	;[BP-2] - Count
	push BX
	push SI
	push DX
	push CX
	call _GetChainLength
	mov [BP-2], AX
	mov AL, [BX+SI]
	mov CH, MASK_CLEAR
	rol CH, CL
.clearLoop:
	cmp WORD [BP-2], 0
	jz .clearEnd
	dec WORD [BP-2]
	and AL, CH
	cmp CL, 3
	je .nextBlock
	inc CL
	dec DX
	rol CH, 1
	jmp .clearLoop

.nextBlock:
	mov [BX+SI], AL
	call _SeekHeapBlock
	mov AL, [BX+SI]
	mov CH, MASK_CLEAR
	jmp .clearLoop

.clearEnd:
	mov [BX+SI], AL
	pop CX
	pop DX
	pop SI
	pop BX
	mov SP, BP
	pop BP
	ret

_GetChainAddress:
	call _GetChainID
	call _GetIDAddress
	ret

_GetAddressID: ;_GetAddressID(Address@AX)
	push CX
	sub AX, [DI+HeapHeader.allocStart]
	mov CL, [DI+HeapHeader.blockShift]
	shr AX, CL
	pop CX
	ret

_GetIDAddress: ;_GetIDAddress(ID@AX)
	push CX
	mov CL, [DI+HeapHeader.blockShift]
	shl AX, CL
	add AX, [DI+HeapHeader.allocStart]
	pop CX
	ret

_GetChainID:
	push BX
	mov AX, [BX+BlockHeader.size]
	sub AX, DX
.seekLoop:
	cmp WORD [BX+BlockHeader.parent], 0
	jz .seekEnd
	mov BX, [BX+BlockHeader.parent]
	add AX, [BX+BlockHeader.size]
	jmp .seekLoop

.seekEnd:
	pop BX
	ret

_SetChainID: ;_SetChainID(ID@AX)
	push BP
	mov BP, SP
	sub SP, 2
	;[BP-2] - tempID
	mov [BP-2], AX
	call _ResetMemRegs
.seekLoop:
	mov AX, [BX+BlockHeader.size]
	cmp [BP-2], AX
	jb .seekEnd
	sub [BP-2], AX
	mov BX, [BX+BlockHeader.next]
	test BX, BX
	jz .fail
	jmp .seekLoop
.seekEnd:
	mov DX, AX
	mov SI, [BP-2]
	sub DX, SI
	mov CL, [BP-2]
	and CL, 3
	shr SI, 2
	add SI, BlockHeader_size
.endOK:
	xor AX, AX
.end:
	mov SP, BP
	pop BP
	ret
.fail:
	call _ResetMemRegs
	mov AX, 0xFFFF
	jmp .end

_GetChainAtAddress: ;_GetChainAtAddress(Address@AX)
	call _GetAddressID
	call _SetChainID
	ret

_NextFreeChain: ;_NextFreeChain(size@AX)
	push BP
	mov BP, SP
	sub SP, 4
	;[BP-2] - requested length
	;[BP-4] - current free length
	push BX
	push SI
	push DX
	push CX
	mov [BP-2], AX
	xor AX, AX
	mov [BP-4], AX
	mov AL, [BX+SI]
	shr AL, CL
.checkLoop:
	mov CH, AL
	mov AX, [BP-4]
	cmp AX, [BP-2]
	mov AL, CH
	jge .endOK
	test CL, CL
	jnz .checkBlock
	test AL, MASK_EMPTY
	jnz .checkBlock
	add WORD [BP-4], 4
	call _SeekHeapBlock
	not AX
	test AX, AX
	jz .fail
	mov AL, [BX+SI]
	jmp .checkLoop

.checkBlock:
	test AL, MASK_SET
	jnz .resetLen
	inc WORD [BP-4]
	cmp CL, 3
	je .nextBlock
	inc CL
	dec DX
	shr AL, 1
	jmp .checkLoop

.nextBlock:
	call _SeekHeapBlock
	not AX
	test AX, AX
	jz .fail
	mov AL, [BX+SI]
	jmp .checkLoop

.resetLen:
	xor AX, AX
	mov [BP-4], AX
	call _SkipChain
	add SP, 8	;Clear stored state
	push BX
	push SI
	push DX
	push CX
	mov AL, [BX+SI]
	shr AL, CL
	jmp .checkLoop

.endOK:
	xor AX, AX
.end:
	pop CX
	pop DX
	pop SI
	pop BX
	mov SP, BP
	pop BP
	ret
.fail:
	mov AX, 0xFFFF
	jmp .end

_SeekEndChain:
	mov AL, [BX+SI]
	shr AL, CL
	test AL, MASK_LINK
	jz .end
.seekLoop:
	test AL, MASK_LINK
	jz .seekEnd
	cmp CL, 3
	je .nextBlock
	inc CL
	dec DX
	shr AL, 1
	jmp .seekLoop

.seekEnd:
	test AL, MASK_SET
	jz .chainFix
.end:
	ret
.nextBlock:
	call _SeekHeapBlock
	mov AL, [BX+SI]
	jmp .seekLoop

.chainFix:
	mov AL, [BX+SI]
	mov CH, MASK_UNLINK
	rol CH, CL
	and AL, CH
	mov [BX+SI], AL
	ret

_SkipChain:
	call _SeekEndChain
	mov AL, [BX+SI]
	shr AL, CL
	test AL, MASK_SET
	jz .end
	cmp CL, 3
	je _SeekHeapBlock	;will also return from _SkipChain
	inc CL
	dec DX
.end:
	ret

_AllocBlockTable:
	push BP
	mov BP, SP
	sub SP, 10
	;[BP-2] - table size (blocks)
	;[BP-4] - size to allocate (bytes)
	;[BP-6] - temp unalloc value
	;[BP-8] - temp next ptr
	;[BP-10] - parent ptr
	push BX
	push SI
	push DX
	push CX
	call _ResetMemRegs
	mov AX, [DI+HeapHeader.unalloc]
	test AX, AX
	jz .endOK
	mov [BP-6], AX
	mov CX, 128 - BlockHeader_size
	shl CX, 2
	cmp AX, CX
	jb .lastTable
	mov [BP-2], CX
	mov WORD [BP-4], 128
.allocate:
	mov WORD [DI+HeapHeader.unalloc], 0
	mov AX, [BP-4]
	push AX
	push DI
	call MemAlloc
	mov [BP-8], AX
	test AX, AX
	mov AX, [BP-6]
	mov [DI+HeapHeader.unalloc], AX
	jz .fail
.tableSeekLoop:
	mov AX, [BX+BlockHeader.next]
	test AX, AX
	jz .seekEnd
	mov BX, AX
	jmp .tableSeekLoop

.lastTable:
	mov AX, [BP-6]
	mov [BP-2], AX
	test AX, 3
	jz .sizeAligned
	shr AX, 2
	inc AX
.setSize:
	add AX, BlockHeader_size
	mov [BP-4], AX
	jmp .allocate

.sizeAligned:
	shr AX, 2
	jmp .setSize

.seekEnd:
	mov [BP-10], BX
	mov AX, [BP-8]
	mov [BX+BlockHeader.next], AX
	mov BX, AX
	mov CX, [BP-4]
	push ES
	push DI
	mov DI, BX
	mov AX, DS
	mov ES, AX
	xor AX, AX
	rep stosb
	pop DI
	pop ES
	mov AX, [BP-10]
	mov [BX+BlockHeader.parent], AX
	mov AX, [BP-2]
	mov [BX+BlockHeader.size], AX
	sub [DI+HeapHeader.unalloc], AX
.endOK:
	xor AX, AX
.end:
	pop CX
	pop DX
	pop SI
	pop BX
	mov SP, BP
	pop BP
	ret
.fail:
	mov AX, 0xFFFF
	jmp .end

_BytesFromBlocks: ;_BytesFromBlocks(blocks@AX)
	push CX
	mov CL, [DI+HeapHeader.blockShift]
	shl AX, CL
	pop CX
	ret

_BlocksFromBytes: ;_BlocksFromBytes(bytes@AX)
	push CX
	mov CL, [DI+HeapHeader.blockShift]
	mov CH, [DI+HeapHeader.blockSize]
	dec CH
	test AL, CH
	jz .aligned
	shr AX, CL
	inc AX
	pop CX
	ret
.aligned:
	shr AX, CL
	pop CX
	ret

;Allocator functions

MemFree: ;void MemFree(void *heapStart, void *ptr)
	push BP
	mov BP, SP
	push BX
	push DI
	push SI
	mov AX, [BP+4]	;heapStart
	push AX
	call _InitMemRegs
	mov CH, [DI+HeapHeader.blockSize]
	dec CH
	mov AX, [BP+6]	;ptr
	test AL, CH
	jnz .invalid
	call _GetChainAtAddress
	mov AL, [BX+SI]
	shr AL, CL
	test AL, MASK_SET
	jz .invalid
	call _ClearChain
	xor AX, AX
.end:
	pop SI
	pop DI
	pop BX
	mov SP, BP
	pop BP
	ret 4
.invalid:
	int3	;Invoke debugger on invalid addr or chain
	mov AX, 0xFFFF
	jmp .end

MemAlloc: ;void *MemAlloc(void *heapStart, int length)
	push BP
	mov BP, SP
	sub SP, 2
	;[BP-2] - block length
	push BX
	push DI
	push SI
	mov AX, [BP+4]
	push AX
	call _InitMemRegs
	mov AX, [BP+6]
	call _BlocksFromBytes
	mov [BP-2], AX
	call _NextFreeChain
	not AX
	test AX, AX
	jz .fail
	mov AX, [BP-2]
	call _SetChainLength
	not AX
	test AX, AX
	jz .fail
	call _GetChainAddress
.end:
	pop SI
	pop DI
	pop BX
	mov SP, BP
	pop BP
	ret 4
.fail:
	xor AX, AX
	jmp .end

MemRealloc: ;void *MemRealloc(void *heapStart, void *ptr, int length)
	push BP
	mov BP, SP
	sub SP, 4
	;[BP-2] - block length
	;[BP-4] - chain length
	push BX
	push DI
	push SI
	mov AX, [BP+4]
	push AX
	call _InitMemRegs
	mov CH, [DI+HeapHeader.blockSize]
	dec CH
	mov AX, [BP+6]	;ptr
	test AL, CH
	jnz .invalid
	call _GetChainAtAddress
	mov AL, [BX+SI]
	shr AL, CL
	test AL, MASK_SET
	jz .invalid
	mov AX, [BP+8]
	call _BlocksFromBytes
	mov [BP-2], AX
	call _GetChainLength
	mov [BP-4], AX
	cmp AX, [BP-2]
	je .sameChain
	mov AX, [BP-2]
	call _SetChainLength
	not AX
	test AX, AX
	jnz .sameChain
	mov AX, [BP-4]
	call _BytesFromBlocks
	mov CX, AX
	mov AX, [BP+8]
	push CX
	push AX
	push BX
	call MemAlloc
	pop CX
	test AX, AX
	jz .fail
	push ES
	mov DI, AX
	push DI
	mov SI, [BP+6]
	mov AX, DS
	mov ES, AX
	xor AX, AX
	rep movsb
	pop ES
	pop DI
	mov AX, [BP+6]
	push AX
	push BX
	call MemFree
	mov AX, DI
.end:
	pop SI
	pop DI
	pop BX
	mov SP, BP
	pop BP
	ret 6
.sameChain:
	mov AX, [BP+6]
	jmp .end
.fail:
	int3	;Invoke debugger when failing to allocate
.invalid:
	xor AX, AX
	jmp .end

STRUC HeapHeader
.size resw 1
.allocStart resw 1
.unalloc resw 1
.blockSize resb 1
.blockShift resb 1
ENDSTRUC

STRUC BlockHeader
.parent resw 1
.next resw 1
.size resw 1
ENDSTRUC

MASK_CLEAR EQU 11101110b
MASK_SET EQU 00000001b
MASK_SET_LINK EQU 00010001b
MASK_LINK EQU 00010000b
MASK_UNLINK EQU 11101111b
MASK_EMPTY EQU 00001111b