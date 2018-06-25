BITS 16
SECTION .text

Int3Handler:
    ;Flags  -[BP+22]
    ;Ret CS -[BP+20]
    ;Ret IP -[BP+18]
    pusha   ;[BP+2] - [BP+16]
    push BP
    mov BP, SP
    sub SP, 2
    push AX ;[BP-4]
    mov AX, [BP+20]
    cmp AX, 0xF000
    jae .intret ;BIOS segment, don't interrupt

    pusha
    push DS
    mov AX, KRN_SEG
    mov DS, AX
    mov AL, [_ScreenPage]
    mov [BP-2], AL
    push 3
    call SetScreenPage
    call ClearScreen
    push _TrapStr
    call PrintTitle
    pop DS
    popa

    mov AX, [BP+22]
    and AX, 0xFEFF  ;Make sure TF is not set
    push AX
    popf    ;Load flags before interrupt
    mov AX, [BP]
    push AX ;Old BP
    mov AX, [BP-4]
    push AX ;Old AX
    lea AX, [BP+22]
    push AX ;Old SP
    mov AX, [BP+18]
    push AX ;Old IP
    mov AX, [BP+20]
    push AX ;Old CS
    call _DumpRegisters

    push DS
    mov AX, KRN_SEG
    mov DS, AX
    call PrintNewLine
    push _MemStr
    call PrintString
    mov AX, 16
    or AH, 128
    push AX
    mov AX, [BP+20]
    push AX
    mov AX, [BP+18]
    push AX
    call DumpMemory
    ;TODO: Dump stack and stack trace
    push _DbgPrompt
    call PrintString
.readKeyLoop:
    call GetKey
    call _ChrToUppercase
    cmp AL, 'C'
    je .continue
    cmp AL, 'S'
    je .trapStep
    cmp AL, 'V'
    je .toggleV
    jmp .readKeyLoop
.trapStep:
    mov AX, [BP+22]
    or AX, 0x100
    mov [BP+22], AX
    jmp .promptClean
.continue:
    mov AX, [BP+22]
    and AX, 0xFEFF
    mov [BP+22], AX
    jmp .promptClean
.toggleV:
    mov AX, [BP-2]
    not AH
    mov [BP-2], AX
    test AH, 0xF0
    jz .restore
    push AX
    call SetScreenPage
    jmp .readKeyLoop
.restore:
    push 3
    call SetScreenPage
    jmp .readKeyLoop
.promptClean:
    mov AX, [BP-2]
    push AX
    call SetScreenPage
    pop DS
.intret:
    mov SP, BP
    pop BP
    popa
    iret

SECTION .data
_TrapStr db 'Debugger Breakpoint Hit', 0
_MemStr db 'Next instructions: ', 0
_DbgPrompt db '(c)ontinue, (s)tep, toggle (v)iew', 0