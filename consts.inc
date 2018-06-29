KRN_SEG EQU 0x7C0
SDA_SEG EQU 0x70
BSEC_SEG EQU 0x50
FAT_SEG EQU 0xA00
FATRD_SEG EQU 0xA40
SDA_OFFS EQU 0x200
RD_OFFS EQU 0x400

STRUC BSEC
resb 3	;jmp + nop
.OEM resb 8	;OEM ID
.bps resw 1	;Bytes per sector
.spc resb 1	;Sectors per cluster
.ressec resw 1	;Reserved sectors
.fatc resb 1	;FAT Copies
.rentc resw 1	;Root entry count
.secs resw 1	;Sector count small (for less than 65536 sectors)
.md resb 1	;Media descriptor
.secf resw 1	;Sectors per FAT
.sect resw 1	;Sectors per head
.hdc resw 1	;Head count
.hsec resd 1	;Hidden sectors
.secl resd 1	;Sector count large
.dn resb 1	;Drive number
resb 1
.ntsig resb 1	;Extended boot signature
.vsn resd 1	;Volume serial number
.vlbl resb 11
.fst resb 8	;File system type
ENDSTRUC

STRUC SDA
.DAP resb 16
.LBA resb 1
.FATo resw 1	;FAT Offset
.FATdo resw 1	;FAT Dir Offset
.FATds resw 1	;FAT Dir Size
.fsfdo resw 1	;FS File Data Offset
.sFAT resb 1	;Selected FAT
.cfsec resw 1	;Cached FAT Sector
.cfrds resw 1	;Cached FAT Root Dir Sector
.csds resw 1	;Cached SubDir Sector
ENDSTRUC