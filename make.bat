@set NASM_PATH=

%NASM_PATH%nasm -f bin bootload.asm -o bootload.bin
@IF /I "%ERRORLEVEL%" NEQ "0" exit /b %ERRORLEVEL%
%NASM_PATH%nasm -f bin kernel.asm -o kernel.bin
@IF /I "%ERRORLEVEL%" NEQ "0" exit /b %ERRORLEVEL%
%NASM_PATH%nasm -f bin test.asm -o test.bin
@IF /I "%ERRORLEVEL%" NEQ "0" exit /b %ERRORLEVEL%
%NASM_PATH%nasm -f bin system.asm -o system.bin
@IF /I "%ERRORLEVEL%" NEQ "0" exit /b %ERRORLEVEL%
node makefs
@IF /I "%ERRORLEVEL%" NEQ "0" exit /b %ERRORLEVEL%
copy /Y/B bootload.bin+fat.bin+rootdir.bin+fs_data.bin output.bin
@IF /I "%ERRORLEVEL%" NEQ "0" exit /b %ERRORLEVEL%