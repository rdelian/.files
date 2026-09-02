@echo off
setlocal enabledelayedexpansion
set "args=%*"
:: fix zig 0.16 UnknownOperatingSystem: x86_64-pc-windows-msvc -> x86_64-windows-msvc
set "args=!args:pc-windows=windows!"
zig cc !args!
