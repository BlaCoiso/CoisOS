BITS 16
%include "system.inc"
SECTION .text
push TitleStr
push PrintTitle
call KernelCall
push TestStr
push PrintString
call KernelCall
;TODO: More testing code
retf

SECTION .data
TestStr db 'This is a string', 0xD, 0xA, 0
TitleStr db 'This is a title', 0
