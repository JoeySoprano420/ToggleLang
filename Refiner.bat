@echo off
setlocal EnableDelayedExpansion

:: Start timing
set startTime=%time%

:: Initialize variables
set "sourceFile=source.tl"
set "outputJson=program.json"
set "outputAsm=program.asm"
set "errorFlag=0"
set "lineNumber=0"
set "functionStack="
set "maxStackDepth=100"

:: Step 1: Read ToggleLang source file into JSON
echo Parsing ToggleLang source code...
(
    echo {
    echo   "main": {
    echo     "type": "function",
    echo     "operations": [
) > %outputJson%

:: Read source file and parse line by line
for /f "tokens=*" %%i in (%sourceFile%) do (
    set /a lineNumber+=1
    set "line=%%i"
    
    :: Skip empty lines or comments
    if "!line!"=="" goto :continue
    echo !line! | findstr /r "^//" > nul && goto :continue

    :: Process operations
    call :process_line "!line!"
    
    :continue
)

echo   ]
    echo   }
    echo } >> %outputJson%

:: Step 2: Convert JSON to Assembly
echo Converting JSON to Assembly...
echo ; ToggleLang to Assembly Code > %outputAsm%
echo section .data >> %outputAsm%
echo result dd 0 >> %outputAsm%
echo sensorData dd 0 >> %outputAsm%
echo message db 'Hello, World!', 0 >> %outputAsm%
echo message_length equ $-message >> %outputAsm%
echo userInput db 256 dup(0) >> %outputAsm%
echo varStore dd 0 >> %outputAsm%

echo section .text >> %outputAsm%

echo _start: >> %outputAsm%

for /f "tokens=*" %%i in (%outputJson%) do (
    set "operation=%%i"
    call :generate_assembly "!operation!"
)

:: Error Handling
if !errorFlag! == 1 (
    echo Compilation failed due to errors!
    exit /b 1
)

:: Step 3: Assemble and Link Assembly Code
echo Assembling...
nasm -f win64 %outputAsm% -o program.obj

echo Linking...
GoLink /entry _start program.obj

:: Step 4: Execute
echo Running program...
program.exe

:: End timing
set endTime=%time%

:: Calculate elapsed time
call :elapsedTime %startTime% %endTime%

endlocal
exit /b

:: Process each line
:process_line
set "line=%~1"

:: Compute operation
echo !line! | findstr /i "^compute" > nul && (
    set "args=!line:compute=!"
    echo       { "type": "compute", "arguments": [!args!], "result": "result" }, >> %outputJson%
    exit /b
)

:: Print operation
echo !line! | findstr /i "^print" > nul && (
    set "message=!line:print=!"
    echo       { "type": "print", "message": "!message!" }, >> %outputJson%
    exit /b
)

:: Return operation
echo !line! | findstr /i "^return" > nul && (
    set "value=!line:return=!"
    echo       { "type": "return", "value": "!value!" }, >> %outputJson%
    exit /b
)

:: Input operation
echo !line! | findstr /i "^input" > nul && (
    set "var=!line:input=!"
    echo       { "type": "input", "variable": "!var!" }, >> %outputJson%
    exit /b
)

:: If operation
echo !line! | findstr /i "^if" > nul && (
    set "condition=!line:if=!"
    echo       { "type": "if", "condition": "!condition!" }, >> %outputJson%
    exit /b
)

:: Loop operation
echo !line! | findstr /i "^loop" > nul && (
    set "iterations=!line:loop=!"
    echo       { "type": "loop", "iterations": !iterations! }, >> %outputJson%
    exit /b
)

:: Store operation
echo !line! | findstr /i "^store" > nul && (
    set "args=!line:store=!"
    echo       { "type": "store", "arguments": [!args!] }, >> %outputJson%
    exit /b
)

:: Load operation
echo !line! | findstr /i "^load" > nul && (
    set "args=!line:load=!"
    echo       { "type": "load", "arguments": [!args!] }, >> %outputJson%
    exit /b
)

:: Error handling
echo !line! | findstr /i "^error" > nul && (
    echo Error on line %lineNumber%
    set errorFlag=1
    exit /b 1
)

exit /b

:: Generate Assembly Code
:generate_assembly
set "operation=%~1"

:: Compute Assembly
echo !operation! | findstr /i "compute" > nul && (
    echo     mov eax, [result] >> %outputAsm%
    echo     add eax, 1 >> %outputAsm%
    echo     mov [result], eax >> %outputAsm%
    exit /b
)

:: Print Assembly
echo !operation! | findstr /i "print" > nul && (
    set "message=!operation:~14,-2!"
    echo     ; Print operation >> %outputAsm%
    echo     mov rsi, message >> %outputAsm%
    echo     mov rdx, message_length >> %outputAsm%
    echo     mov rax, 1 >> %outputAsm%
    echo     mov rdi, 1 >> %outputAsm%
    echo     syscall >> %outputAsm%
    exit /b
)

:: Input Assembly
echo !operation! | findstr /i "input" > nul && (
    set "var=!operation:~14,-2!"
    echo     ; Input operation >> %outputAsm%
    echo     mov rax, 0 >> %outputAsm%
    echo     mov rdi, 0 >> %outputAsm%
    echo     mov rsi, userInput >> %outputAsm%
    echo     mov rdx, 256 >> %outputAsm%
    echo     syscall >> %outputAsm%
    exit /b
)

:: If Assembly
echo !operation! | findstr /i "if" > nul && (
    set "condition=!operation:~14,-2!"
    echo     ; If operation >> %outputAsm%
    echo     cmp eax, 0 >> %outputAsm%
    echo     je .endif >> %outputAsm%
    echo     ; (condition is true, execute code) >> %outputAsm%
    echo .endif: >> %outputAsm%
    exit /b
)

:: Loop Assembly
echo !operation! | findstr /i "loop" > nul && (
    set "iterations=!operation:~14,-2!"
    echo     ; Loop operation >> %outputAsm%
    echo     mov ecx, !iterations! >> %outputAsm%
    echo .loop_start: >> %outputAsm%
    echo     ; (loop body) >> %outputAsm%
    echo     loop .loop_start >> %outputAsm%
    exit /b
)

:: Store Assembly
echo !operation! | findstr /i "store" > nul && (
    set "args=!operation:~14,-2!"
    echo     ; Store operation >> %outputAsm%
    echo     mov [varStore], eax >> %outputAsm%
    exit /b
)

:: Load Assembly
echo !operation! | findstr /i "load" > nul && (
    set "args=!operation:~14,-2!"
    echo     ; Load operation >> %outputAsm%
    echo     mov eax, [varStore] >> %outputAsm%
    exit /b
)

exit /b

:: Calculate elapsed time
:elapsedTime
setlocal
set start=%1
set end=%2

set /A startH=%start:~0,2%
set /A startM=%start:~3,2%
set /A startS=%start:~6,2%
set /A startMS=%start:~9,2%

set /A endH=%end:~0,2%
set /A endM=%end:~3,2%
set /A endS=%end:~6,2%
set /A endMS=%end:~9,2%

set /A elapsedMS=endMS-startMS
set /A elapsedS=endS-startS
set /A elapsedM=endM-startM
set /A elapsedH=endH-startH

if %elapsedMS% LSS 0 (
    set /A elapsedMS+=100
    set /A elapsedS-=1
)

if %elapsedS% LSS 0 (
    set /A elapsedS+=60
    set /A elapsedM-=1
)

if %elapsedM% LSS 0 (
    set /A elapsedM+=60
    set /A elapsedH-=1
)

echo Elapsed time: %elapsedH%:%elapsedM%:%elapsedS%.%elapsedMS%
endlocal
exit /b
