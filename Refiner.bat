@echo off
setlocal EnableDelayedExpansion

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
    echo     ; Print operation (To be implemented) >> %outputAsm%
    exit /b
)

exit /b
