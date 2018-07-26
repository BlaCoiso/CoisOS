nasm -f bin bootload.asm -o bootload.bin
@IF /I "%ERRORLEVEL%" NEQ "0" goto :EOF
nasm -f bin kernel.asm -o kernel.bin
@IF /I "%ERRORLEVEL%" NEQ "0" goto :EOF
nasm -f bin test.asm -o test.bin
@IF /I "%ERRORLEVEL%" NEQ "0" goto :EOF
nasm -f bin system.asm -o system.bin
@IF /I "%ERRORLEVEL%" NEQ "0" goto :EOF
node makefs
@IF /I "%ERRORLEVEL%" NEQ "0" goto :EOF
copy /Y/B bootload.bin+fat.bin+rootdir.bin+fs_data.bin output.bin