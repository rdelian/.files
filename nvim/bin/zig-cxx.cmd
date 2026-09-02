@echo off
setlocal enabledelayedexpansion
set "args=%*"
set "args=!args:pc-windows=windows!"
zig c++ !args!
