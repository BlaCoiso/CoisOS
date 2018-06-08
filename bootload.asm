BITS 16
	jmp init
	nop

OEMLabel db 'COISOSV2'
BytesSector dw 512
SectorsCluster db 2 ;2 Sectors per cluster, FS Data
ReservedSectors dw 1 ;1 reserved sector (this sector)
FATCount db 1 ;1 FAT, FS Data
RootEntryCount dw 128 ;128 root dir entries (files/folders/whatever), FS Data
VolumeSectors dw 0xFFFF
MediaType db 0xF8 ;F8 = HDD, disk Data
FATSectors dw 64 ;64 sectors for FAT, FS Data
Disk_SectorsHead dw 32 ;32 sectors per head, disk Data
Disk_HeadCount dw 2 ;2 heads per cylinder, disk Data
HiddenSectors dd 0 
VolumeSectorsLarge dd 0 ;Set in VolumeSectors, only used when VolumeSectors=0
DriveNumber db 0x80 ;Drive number ID, used for I/O
FS_Reserved1 db 0
NT_Signature db 0x29
VolumeSN dd 1861703934 ;Volume Serial Number, hardcoded with random value
VolumeLabel db 'CoisOS v2  '
FSType db 'FAT16   '

init:
	;Stack setup
	cli	;Clear interrupts while stack and registers are being set
	mov AX, 0x90	;Stack base address is 0x900, SS is 0x90
	mov SS, AX
	mov SP, 0x7300	;stack top relative address, 0x7300+0x900 (0x7C00)
	mov BP, SP
	mov CX, 256		;Set counter for sector length in words (div by 2)
	mov AX, 0x7C0	;Set origin data segment (0x07C0:0)
	mov DS, AX
	mov AX, 0x50	;Set destination segment (0x0050:0)
	mov ES, AX
	xor DI, DI		;Clear pointers, data is at offset 0
	xor SI, SI
	cld	;Make sure direction flag is cleared
	rep movsw		;Copy the boot sector from 0x7C00 to 0x500
	mov DS, AX
	sti	;Restore interrupts
	jmp 0x50:main	;Set the new code segment, jump to the copied data
	
main:
	;Now we're in the copied boot sector
	;Register state: AX: 0050h BX: Unknown CX: 0 DX: ??DR SP: 7300h CS: 0050h DS: 0050h ES: 0050h
	mov [DriveNumber], DL	;Save the drive number to be used later
	mov AH, 8
	int 0x13		;Get drive parameters
	jc diskErrorFatal
	and CL, 63		;filter lowest 6 bits
	mov [Disk_SectorsHead], CL	;Save sectors per head
	inc DH
	mov [Disk_HeadCount], DH	;Save heads per cylinder
	mov AX, 0x70	;SDA Segment
	mov FS, AX
	mov AH, 0x41
	mov DL, [DriveNumber]
	mov BX, 0x55AA
	int 0x13		;Check if extensions are supported, if they are, LBA Addressing will be used
	cmp BX, 0xAA55
	jne .noExt
	test CX, 1
	jz .noExt
	;If all checks passed, then we have access to disk extensions
	mov BYTE [FS:0x10], 0xFF	;Set extensions available byte
	mov WORD [EXT_DiskPack], 16	;Set up disk packet length
.noExt:
	mov BX, [ReservedSectors]
	mov [FS:0x11], BX	;FAT Offset is the same as reserved sectors
	mov AX, [FATSectors]
	mov CL, [FATCount]
	mul CX			;Root Dir starts after FAT Size*FAT Count
	add AX, BX
	mov [FS:0x13], AX
	mov BX, [RootEntryCount]
	shr BX, 4		;Each entry is 32 bytes long, 512/32=16, optimization for BX/=16
	mov [FS:0x15], BX
	add AX, BX		;Add the Root Dir offset to its size
	mov [FS:0x17], AX
	;Now the values required to load a file are ready
	mov AX, 0x900	;FAT Copy Offset
	mov ES, AX
	xor BX, BX
	mov CX, 2
	mov AX, [FS:0x11]
	call readSectors;Load 2 sectors from the FAT
	mov BX, 0x400
	mov AX, [FS:0x13]
	call readSectors;Load 2 sectors from the Root Dir
	;Now we're ready to find the file and load it
.findFileLoop: ;BX is file offset (in the root dir)
	mov DI, BX
	mov SI, KernelName
	mov CX, 11	;8+3 name
	repe cmpsb	;Compare the filename
	jz .fileFound
	add BX, 32	;File entry is 32 bytes long
	cmp BX, 0x800;Check if we reached end of cached data
	jae .finderr
	jmp .findFileLoop
.fileFound:
	;ES:BX points to the file entry
	mov BX, [ES:BX+0x1A];Load cluster number
	movzx SI, [SectorsCluster]
	shl SI, 9	;Multiply by 512 to get offset
	xor DI, DI
	;BX contains cluster number
.loadLoop:
	push BX
	push ES
	mov AX, BX
	sub AX, 2	;first 2 clusters aren't "real"
	mov CL, [SectorsCluster]
	mul CX		;AX = Cluster data offset
	add AX, [FS:0x17];Now AX contains the sector number
	mov BX, 0x7C0
	mov ES, BX	;Set buffer segment to 07C0 (0x7C00)
	mov BX, DI	;Set offset pointer
	call readSectors ;Load cluster
	add DI, SI	;Add cluster size in bytes to pointer
	pop ES
	pop BX
	shl BX, 1	;Each cluster is 2 bytes in the table
	mov BX, [ES:BX];Next cluster number
	cmp BX, 0xFFF0
	jb .loadLoop;Not the last cluster, load more
	;If we're here, then the file was probably loaded
	jmp 0x7C0:0	;Jump into kernel
.finderr:
	mov SI, KernelErr
	call print_str
	jmp reboot

;Disk stuff
diskError:
	push AX
	xor AX, AX
	mov DL, [DriveNumber]
	clc		 ;make sure carry flag is not set before reset
	int 0x13 ;reset the drive
	jc diskErrorFatal ;Drive failed to reset
	dec BYTE [DiskErrCount]
	jz diskErrorFatal
	pop AX
	ret
diskErrorFatal:
	mov SI, ErrStr
	call print_str
	jmp reboot

readSectors: ;reads CX sectors starting at AX into ES:BX
	push DX
	test BYTE [FS:0x10], 0xFF
	jz readSectorsCHS	;Extensions not supported, use CHS
readSectorsLBA:
	call setLBA
	push SI
.retry:
	mov AH, 0x42
	mov SI, EXT_DiskPack
	mov DL, [DriveNumber]
	int 0x13	;Read the sectors
	jnc .end
	call diskError
	jmp .retry
.end:
	pop SI
	pop DX
	ret
readSectorsCHS:
	call setCHS
	mov AH, 2
.retry:
	push AX
	mov DL, [DriveNumber]
	int 0x13	;Read the sectors
	jnc .end
	call diskError
	pop AX
	jmp .retry
.end:
	pop AX
	pop DX
	ret

setCHS:
	push BX
	div BYTE [Disk_SectorsHead]	;Get the sector number, AH=sector number
	inc AH		;first sector is 1
	mov BX, AX	;Store it temporarily
	xor AH, AH
	div BYTE [Disk_HeadCount]	;Get the head number, AH=head number, AL=cylinder
	mov CH, AL	;Load cylinder number
	mov AL, CL	;Load sector count
	mov CL, BH	;Load sector start
	mov DH, AH	;Load head number
	pop BX		;Restore buffer pointer
	ret

setLBA:
	mov [EXT_DiskSectorCount], CX
	mov [EXT_OPBufferSegment], ES
	mov [EXT_OPBufferOffset], BX
	mov [EXT_LowerLBA], AX
	ret

;Internal stuff
print_str: ;prints the C string at DS:SI
	push AX
	mov AH, 0xE	;print character
.printloop:
	lodsb
	test AL, AL
	jz .end
	int 0x10
	jmp .printloop
.end: ;String was printed, clean up
	pop AX
	ret

reboot: ;tells the BIOS to reboot the system
	xor AX, AX
	int 0x16	;Wait for key
	xor AX, AX
	int 0x19	;Do it

;DATA
ErrStr db 'Disk Error', 0
KernelName db 'SYSTEM  KRN', 0
KernelErr db 'No Kernel',0
DiskErrCount db 10

times 510-($-$$) db 0 ;Add padding to fill sector
BootSignature dw 0xAA55 ;Required for the BIOS to actually try to boot from this

EXT_DiskPack: ;Disk Access Packet goes here
EXT_DiskSectorCount EQU EXT_DiskPack + 2
EXT_OPBufferOffset EQU EXT_DiskPack + 4
EXT_OPBufferSegment EQU EXT_DiskPack + 6
EXT_LowerLBA EQU EXT_DiskPack + 8
EXT_UpperLBA EQU EXT_DiskPack + 0xC
