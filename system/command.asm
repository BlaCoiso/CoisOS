BITS 16
SECTION .text

HandleCommand: ;void HandleCommand()
	push BP
	mov BP, SP
	sub SP, 6
	;[BP-2] - Copied buffer pointer
	;[BP-4] - Parser temp token/Argument array
	;[BP-6] - Argument count
	push DI
	push SI
	push CmdBuffer
	push StringLength
	call KernelCall
	test AX, AX
	jz .emptyBuf
	inc AX
	push AX
	call MemAlloc
	mov [BP-2], AX
	push CmdBuffer
	push AX
	push StringCopy
	call KernelCall
	mov SI, [BP-2]
	xor DX, DX
	mov [BP-4], DX
	mov [BP-6], DX
	or DL, 1	;Ignore spaces at start
.parserLoop:
	;Parser state (DX):
	; 1 - last char was space
	; 2 - next char is escaped (some\ argument)
	; 4 - single quote wrapping ('long argument')
	; 8 - double quote wrapping ("very long argument")
	; 16- last character made new token
	; 32- next character can't make new token
	lodsb
	test AL, AL
	jz .parserEnd
	and DL, ~32
	test DL, 16
	jz .tokenAllow
	or DL, 32
	and DL, ~16
.tokenAllow:
	test DL, 2
	jnz .skipParse
	cmp AL, '\'
	jne .noEscape
	call .shiftBuf
	or DL, 2
	jmp .parserLoop
.noEscape:
	cmp AL, ' '
	jne .noSpace
	test DL, 12	;Check if arguments are inside quotes
	jnz .parserLoop
	test DL, 33	;Check if argument count can be incremented
	jnz .skipSArgC
	inc WORD [BP-6]
.skipSArgC:
	or DL, 17
	mov BYTE [SI-1], 0	;Split token
	jmp .parserLoop
.noSpace:
	and DL, ~1
	cmp AL, '"'
	jne .noDQuote
	test DL, 4
	jnz .parserLoop
	xor DL, 8
	test DL, 40
	jnz .tempQ
	inc WORD [BP-6]
	or DL, 16
	mov BYTE [SI-1], 0
	push SI
	mov SI, [BP-4]
	mov BYTE [SI], 0
	pop SI
	jmp .parserLoop
.tempQ:
	mov [BP-4], SI
	dec WORD [BP-4]
	jmp .parserLoop
.noDQuote:
	cmp AL, "'"
	jne .parserLoop
	test DL, 8
	jnz .parserLoop
	xor DL, 4
	test DL, 36
	jnz .tempQ
	inc WORD [BP-6]
	or DL, 16
	mov BYTE [SI-1], 0
	push SI
	mov SI, [BP-4]
	mov BYTE [SI], 0
	pop SI
	jmp .parserLoop
.skipParse:
	and DL, ~2
	jmp .parserLoop
.parserEnd:
	test DL, 12
	jz .skipSeekBack
	and DL, ~12
	mov SI, [BP-4]
	inc SI
	jmp .parserLoop
.skipSeekBack:
	test DL, 48
	jnz .skipEndToken
	inc WORD [BP-6]
.skipEndToken:
	mov AX, [BP-6]
	test AX, AX
	jz .bufferCleanup
	shl AX, 1
	push AX
	call MemAlloc
	mov [BP-4], AX
	mov DI, AX
	push CmdBuffer
	push StringLength
	call KernelCall
	mov CX, AX
	mov SI, [BP-2]
	xor DL, DL
.tokenizeLoop:
	test CX, CX
	jz .tokenizeEnd
	dec CX
	mov AL, [SI]
	test AL, AL
	jz .skipEmpty
	test DL, DL
	jnz .nextChar
	or DL, 1
	mov [DI], SI
	inc DI
	inc DI
	jmp .nextChar
.skipEmpty:
	xor DL, DL
.nextChar:
	inc SI
	jmp .tokenizeLoop
.tokenizeEnd:
    push BX
    mov BX, [BP-4]
    mov AX, [BX]
    pop BX
    push AX
    call FindCommand
    test AX, AX
    jz .noCommand
	push BX
    mov BX, AX
    mov CX, [BX+CMD.exec]
	pop BX
	mov AX, [BP-4]
	push AX
	mov AX, [BP-6]
	push AX
	call CX
	jmp .bufferCleanup
.noCommand:
	push cmdNotFound
	push PrintString
	call KernelCall
	;TODO: Find an executable file with the specified name and execute it
.bufferCleanup:
	mov AX, [BP-2]
	push AX
	call MemFree
	mov AX, [BP-4]
	push AX
	call MemFree
.emptyBuf:
	pop SI
	pop DI
	mov SP, BP
	pop BP
	ret

.shiftBuf:
	push SI
.shiftLoop:
	mov AL, [SI]
	mov [SI-1], AL
	test AL, AL
	jz .shiftEnd
	inc SI
	jmp .shiftLoop
.shiftEnd:
	pop SI
	ret

SetUpperCase: ;void SetUpperCase(char *string)
	push BP
	mov BP, SP
	push SI
	mov SI, [BP+4]
.loop:
	lodsb
	test AL, AL
	jz .end
	cmp AL, 'a'
	jb .loop
	cmp AL, 'z'
	ja .loop
	sub AL, 'a'-'A'
	mov [SI-1], AL
	jmp .loop
.end:
	pop SI
	mov SP, BP
	pop BP
	ret 2

FindCommand: ;CMD *FindCommand(char *cmdName)
    push BP
    mov BP, SP
	sub SP, 2
	;[BP-2] - Temp command name buffer
    push BX
    push SI
    push DI
    push ES
    mov AX, DS
    mov ES, AX
    mov BX, cmdTable
	mov AX, [BP+4]
	push AX
	push StringLength
	call KernelCall
	inc AX
	push AX
	call MemAlloc
	mov [BP-2], AX
	mov SI, AX
	mov AX, [BP+4]
	push AX
	push SI
	push StringCopy
	call KernelCall
	push SI
	call SetUpperCase
.loop:
	mov SI, [BP-2]
    mov DI, [BX+CMD.name]
    test DI, DI
    jz .findAlias
    push SI
    push StringLength
    call KernelCall
    mov CX, AX
    inc CX
    repe cmpsb
	jne .nextCmd
    test CX, CX
    jnz .nextCmd
    mov AX, BX
    jmp .end
.nextCmd:
    add BX, CMD_size
    jmp .loop
.findAlias:
	mov BX, aliasTable
.aliasLoop:
	mov SI, [BP-2]
	mov DI, [BX+CMD_AL.name]
	test DI, DI
	jz .notF
	push SI
    push StringLength
    call KernelCall
    mov CX, AX
    inc CX
    repe cmpsb
	jne .nextAlias
    test CX, CX
	jnz .nextAlias
	mov AX, [BX+CMD_AL.ptr]
	jmp .end
.nextAlias:
	add BX, CMD_AL_size
	jmp .aliasLoop
.notF:
    xor AX, AX
.end:
	push AX
	mov AX, [BP-2]
	push AX
	call MemFree
	pop AX
    pop ES
    pop DI
    pop SI
    pop BX
    mov SP, BP
    pop BP
    ret 2

HelpCommand: ;void HelpCommand(int argc, char *argv[])
    push BP
    mov BP, SP
	sub SP, 2
	mov BYTE [BP-2], 0
	;[BP-2]: Command has usage (bool)
    mov CX, [BP+4]
    cmp CX, 1
    ja .getCmdHelp
    push helpCmdStr1
    push PrintString
    call KernelCall
    push BX
	mov BX, cmdTable
.cmdListLoop:
    mov AX, [BX+CMD.name]
	test AX, AX
	jz .listEnd
	mov DX, [BX+CMD.desc]
	test DX, DX
	jz .nextEntry
	push DX
	push AX
	push ' '
	push PrintChar
	call KernelCall
	push PrintString
	call KernelCall
	push helpCmdSep
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
	push PrintNewLine
	call KernelCall
.nextEntry:
	add BX, CMD_size
	jmp .cmdListLoop
.listEnd:
    pop BX
    jmp .end
.getCmdHelp:
	push BX
	mov BX, [BP+6]
	add BX, 2
	mov AX, [BX]
	pop BX
	push AX
	call FindCommand
	test AX, AX
	jz .helpNotFound
	push BX
	mov BX, AX
	mov AX, [BX+CMD.name]
	mov CX, [BX+CMD.desc]
	mov DX, [BX+CMD.usage]
	pop BX
	test CX, CX
	jz .helpNotFound
	test DX, DX
	jz .skipUsage
	push DX
	push AX
	push helpCmdStr4
	mov BYTE [BP-2], 0xFF
.skipUsage:
	push CX
	push helpCmdSep
	push AX
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
	push PrintNewLine
	call KernelCall
	test BYTE [BP-2], 0xFF
	jz .end
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
	push ' '
	push PrintChar
	call KernelCall
	push PrintString
	call KernelCall
	push PrintNewLine
	call KernelCall
	jmp .end
.helpNotFound:
	push helpCmdStr3
	push BX
	mov BX, [BP+6]
	add BX, 2
	mov AX, [BX]
	pop BX
	push AX
	push helpCmdStr2
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
.end:
    mov SP, BP
    pop BP
    ret 4

SECTION .data
STRUC CMD
.name resw 1
.exec resw 1
.desc resw 1
.usage resw 1
ENDSTRUC

STRUC CMD_AL
.name resw 1
.ptr resw 1
ENDSTRUC

cmdNotFound db 'Command not found.', 0xA, 0

helpCmdSep db ' - ', 0
helpCmdStr1 db 'List of available commands:', 0xA, 0
helpCmdStr2 db 'No help found for command "', 0
helpCmdStr3 db '".', 0xA, 0
helpCmdStr4 db ' Usage: ', 0
helpCmdName db 'HELP', 0
helpCmdDesc db 'Displays help for commands', 0
helpCmdUse db '[command]', 0

SECTION .bss
CmdBuffer resb 100