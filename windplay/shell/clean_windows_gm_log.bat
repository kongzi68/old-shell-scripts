@echo off
::设置游戏程序所在的分区
::设置游戏目录的关键词
set DIR_NAME="D:\tmp"
set DIR_KEY="3jianhao"

::打印目录
dir /B /AD %DIR_NAME% |find %DIR_KEY% > dir_list.txt
echo "=============================="
for /f "delims=" %%i in ( dir_list.txt ) do (
    forfiles /p %DIR_NAME%\%%i\log\ERROR\ /m *.log /c " cmd /c echo @path"
)
del dir_list.txt
::pause