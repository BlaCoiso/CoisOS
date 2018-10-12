ASM = nasm
ASM_FLAGS = -f bin
ASM_Targets = bootload.bin kernel.bin system.bin test.bin

all: output.bin

bootload.bin: bootload.asm
kernel.bin: kernel.asm modules/*.asm
system.bin: system.asm system.inc system/*.asm
test.bin: test.asm system.inc

fat.bin rootdir.bin fs_data.bin: kernel.bin system.bin test.bin
	node makefs

output.bin: bootload.bin fat.bin rootdir.bin fs_data.bin
	dd if=bootload.bin of=output.bin bs=512 count=1
	dd if=fat.bin of=output.bin conv=notrunc oflag=append
	dd if=rootdir.bin of=output.bin conv=notrunc oflag=append
	dd if=fs_data.bin of=output.bin conv=notrunc oflag=append

$(ASM_Targets):
	$(ASM) $(ASM_FLAGS) $< -o $@

run:
	qemu-system-i386 -drive format=raw,file=output.bin -monitor stdio
