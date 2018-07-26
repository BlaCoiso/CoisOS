boot:
	nasm -f bin bootload.asm -o bootload.bin
	nasm -f bin kernel.asm -o kernel.bin
	nasm -f bin test.asm -o test.bin
	nasm -f bin system.asm -o system.bin
	node makefs
	dd if=bootload.bin of=output.bin bs=512 count=1
	dd if=fat.bin of=output.bin conv=notrunc oflag=append
	dd if=rootdir.bin of=output.bin conv=notrunc oflag=append
	dd if=fs_data.bin of=output.bin conv=notrunc oflag=append
run:
	qemu-system-i386 -drive format=raw,file=output.bin -monitor stdio
