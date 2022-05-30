@echo off
tasm32 /mx /m3 /z /q un-te
tlink32 -x /Tpe /aa /c un-te,tEunlock.exe,, c:\windoze\import32.lib,,teunlock.res
del *.obj
