BITS 16
%include "system.inc"
[map all system.map]
SECTION .text

SysInit:
	push BP
	mov BP, SP
	push 1
	push SetScreenPage
	call KernelCall
	push ClearScreen
	call KernelCall
	call AllocInit
	call SysMain
	push 0
	push SetScreenPage
	call KernelCall
	mov SP, BP
	pop BP
	retf

SysMain:
	push BP
	mov BP, SP
	push initStr
	push PrintString
	call KernelCall
	call CommandLoop
	mov SP, BP
	pop BP
	ret

;;Command handling

CommandLoop:
	push BP
	mov BP, SP
	mov BYTE [canExit], 0
.loop:
	push prompt
	push PrintString
	call KernelCall
	push CmdBuffer
	push StringLength
	call KernelCall
	test AX, AX
	jz .skipEmpty
	push DI
	push ES
	mov CX, AX
	mov AX, DS
	mov ES, AX
	mov DI, CmdBuffer
	xor AL, AL
	rep stosb
	pop ES
	pop DI
.skipEmpty:
	push 100
	push CmdBuffer
	push ReadStringSafe
	call KernelCall
	push PrintNewLine
	call KernelCall
	call HandleCommand
	test BYTE [canExit], 0xFF
	jz .loop
	mov SP, BP
	pop BP
	ret

;;Commands

TestCommand: ;void TestCommand(int argc, char *argv[])
	push BP
	mov BP, SP
	push testCmdStr1
	push PrintString
	call KernelCall
	mov AX, [BP+4]
	push AX
	push PrintUInt
	call KernelCall
	push PrintNewLine
	call KernelCall
	xor CX, CX
.argLoop:
	push CX
	push CX
	push testCmdStr2
	push PrintString
	call KernelCall
	pop CX
	push CX
	push CX
	push PrintUInt
	call KernelCall
	pop CX
	shl CX, 1
	add CX, [BP+6]
	push BX
	mov BX, CX
	mov CX, [BX]
	pop BX
	push CX
	push testCmdStr3
	push PrintString
	call KernelCall
	push PrintString
	call KernelCall
	push testCmdStr4
	push PrintString
	call KernelCall
	pop CX
	inc CX
	cmp CX, [BP+4]
	jb .argLoop
	mov SP, BP
	pop BP
	ret 4

ExitCommand:
	mov BYTE [canExit], 0xFF
	ret 4

%include "system/command.asm"

SECTION .data
initStr db 'CoisOS Console v0.0 (test version)', 0xA
db 'For a list of commands, type "help"', 0xA, 0
prompt db 'CoisOS>', 0
canExit db 0

cmdTable	dw helpCmdName, HelpCommand, helpCmdDesc, helpCmdUse
	dw testCmdName, TestCommand, testCmdDesc, testCmdUse
exitCmd 	dw exitCmdName, ExitCommand, exitCmdDesc, 0
	dw 0, 0, 0, 0

aliasTable dw exitCmdName1, exitCmd, 0, 0

testCmdStr1 db 'Test Command - Argument Count: ', 0
testCmdStr2 db 'Argument ', 0
testCmdStr3 db ': "', 0
testCmdStr4 db '"', 0xA, 0
testCmdName db 'TEST', 0
testCmdDesc db 'Tests the command handling and argument parsing', 0
testCmdUse db 'arguments...', 0

exitCmdName db 'EXIT', 0
exitCmdName1 db 'QUIT', 0
exitCmdDesc db 'Exits the command line interpreter', 0

%include "system/memory.asm"