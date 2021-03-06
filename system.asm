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
	push 8
	push 0xFFFF-0xAC00
	push heapStart
	push InitHeap
	call KernelCall
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
	push 99
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

FileList:
	push BP
	mov BP, SP
	sub SP, 6
	;[BP-2] - Filename Buffer
	;[BP-4] - File Count
	push GetFileCount
	call KernelCall
	mov [BP-4], AX
	push AX	;Count (GetTokenArray)
	push AX	;Count (ListFiles)
	mov CL, 13
	mul CL
	inc AL
	push AX
	call malloc	
	mov [BP-2], AX
	push 0	;Start
	push AX	;Buffer
	push ListFiles
	call KernelCall
	push AX	;Length
	mov AX, [BP-2]
	push AX	;Buffer
	call GetTokenArray
	mov BX, AX
	push BX
	push BX
	push SI
	xor SI, SI
	shl WORD [BP-4], 1
.loop:
	push GetCursorPos
	call KernelCall
	mov CX, SI
	shl CX, 3
	and CL, 63
	mov AL, CL
	push AX
	push SetCursorPos
	call KernelCall
	mov AX, [BX+SI]
	inc SI
	inc SI
	push AX
	push PrintString
	call KernelCall
	cmp SI, [BP-4]
	je .end
	mov AX, SI
	shr AX, 1
	mov CL, 5
	div CL
	test AH, AH
	jnz .loop
	push PrintNewLine
	call KernelCall
	jmp .loop
.end:
	push PrintNewLine
	call KernelCall
	pop SI
	pop BX
	call free
	mov AX, [BP-2]
	push AX
	call free
	mov SP, BP
	pop BP
	ret 4

RunTestProg:
	push BP
	mov BP, SP
	push 0x1000
	push 0	;0x1000:0 | 0x10000
	push rtestProgName
	push ReadFile
	call KernelCall
	test AX, AX
	jnz .fail
	push 0x1000
	push 0
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	push ExecProgram
	call KernelCall
	jmp .end
.fail:
	push rtestFailStr
	push PrintString
	call KernelCall
.end:
	mov SP, BP
	pop BP
	ret 4

ClearCommand:
	push ClearScreen
	call KernelCall
	ret 4

TryExecProgram:
	push BP
	mov BP, SP
	push BX
	mov BX, [BP+6]
	mov AX, [BX]
	push AX
	call FindProgramEntry
	test AX, AX
	jnz .execFile
	push cmdNotFoundStr
	push PrintString
	call KernelCall
	jmp .cleanup
.execFile:
	push 0x1000
	push 0
	push AX
	push ReadFileEntry
	call KernelCall
	push 0x1000
	push 0
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	push ExecProgram
	call KernelCall
.cleanup:
	pop BX
	mov SP, BP
	pop BP
	ret 4

FindProgramEntry:
	push BP
	mov BP, SP
	sub SP, 4
	;[BP-2] - Filename buffer
	;[BP-4] - File Entry ID
	mov AX, [BP+4]
	push AX
	push AX
	push StringLength
	call KernelCall
	add AX, 5	;Reserve 4 bytes for extension and 1 for null terminator
	push AX
	call malloc
	mov [BP-2], AX
	push AX
	push StringCopy
	call KernelCall
	mov AX, [BP-2]
	push AX
	push AX
	call SetUpperCase
	push FindFile8_3
	call KernelCall
	cmp AX, 0xFFFF
	jne .fileFound
	mov AX, [BP-2]
	push AX
	push FindFile
	call KernelCall
	mov [BP-4], AX
	;TODO: Check for extension and if it's a valid extension
	push cmdExecExt
	mov AX, [BP-2]
	push AX
	push StringConcat
	call KernelCall
	mov AX, [BP-2]
	push AX
	push FindFile
	call KernelCall
	cmp AX, 0xFFFF
	jne .fileFound
	mov AX, [BP-4]
	cmp AX, 0xFFFF
	jne .fileFound
	;No file was found, nothing to do
	xor AX, AX
.fileFound:
	mov [BP-4], AX
.cleanup:
	mov AX, [BP-2]
	push AX
	call free
	mov AX, [BP-4]
	mov SP, BP
	pop BP
	ret 2

malloc:	;void *malloc(int size)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	push AX
	push heapStart
	push MemAlloc
	call KernelCall
	mov SP, BP
	pop BP
	ret 2

realloc:	;void *realloc(void *ptr, int size)
	push BP
	mov BP, SP
	mov AX, [BP+6]
	push AX
	mov AX, [BP+4]
	push AX
	push heapStart
	push MemRealloc
	call KernelCall
	mov SP, BP
	pop BP
	ret 4

free:	;void free(void *ptr)
	push BP
	mov BP, SP
	mov AX, [BP+4]
	push AX
	push heapStart
	push MemFree
	call KernelCall
	mov SP, BP
	pop BP
	ret 2

%include "system/command.asm"

SECTION .data
initStr db 'CoisOS Console v0.1 (test version)', 0xA
db 'For a list of commands, type "help"', 0xA, 0
prompt db 'CoisOS>', 0
canExit db 0

cmdTable	dw helpCmdName, HelpCommand, helpCmdDesc, helpCmdUse
	dw testCmdName, TestCommand, testCmdDesc, testCmdUse
exitCmd 	dw exitCmdName, ExitCommand, exitCmdDesc, 0
	dw flistCmdName, FileList, flistCmdDesc, 0
	dw rtestCmdName, RunTestProg, rtestCmdDesc, 0
	dw clearCmdName, ClearCommand, clearCmdDesc, 0
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

flistCmdName db 'LIST', 0
flistCmdDesc db 'Lists the files in the current directory', 0

rtestCmdName db 'RUNTEST', 0
rtestCmdDesc db 'Runs the test program', 0
rtestFailStr db 'Failed to load test program.', 0xA, 0
rtestProgName db 'test.bin', 0

clearCmdName db 'CLEAR', 0
clearCmdDesc db 'Clears the screen', 0

cmdNotFoundStr db 'Command or program not found.', 0xA, 0
cmdExecExt db '.BIN', 0		;TODO: Executable extension thing

SECTION .bss

SECTION .dynAlloc vfollows=.bss nobits
heapStart: