BITS 16
%include "system.inc"
SECTION .text

push TitleStr
push PrintTitle
call KernelCall

push TestStr
push PrintString
call KernelCall

push 0xA5DF
push PrintHex
call KernelCall

push PrintNewLine
call KernelCall
push 54321

push PrintUInt
call KernelCall

push PrintNewLine
call KernelCall

push -12345
push PrintInt
call KernelCall

push PrintNewLine
call KernelCall

push InpStr
push PrintString
call KernelCall

push 12
push BuffFill1
push ReadStringSafe
call KernelCall

push PrintNewLine
call KernelCall

push 20
push BuffTest1
push ReadStringSafe
call KernelCall

push PrintNewLine
call KernelCall

push 15
push Buff1
push ReadStringSafe
call KernelCall

push PrintNewLine
call KernelCall
;TODO: More testing code
retf

SECTION .data
TestStr db 'This is a string', 0xD, 0xA, 0
TitleStr db 'This is a title', 0
InpStr db 'Test Input: ', 0
BuffFill1 db 'Input text 1', 0
BuffTest1 db 0, 'This should not be printed', 0

SECTION .bss
Buff1 resb 16
