# tEunlock - Unpacker for Telock (all versions).

#### Written in 2000 September.

[Original package](https://defacto2.net/f/aa2eb47)

```
 ╓══════════════════════════════════════════════════════════════════════════╖
 ║                 ...:UNPACKER FOR TELOCK (all versions):...               ║
 ║┌══════════════════════════════─══╤════╤══─══════════════════════════════┐║
 ║│     ···[uNPACKER iNFO]···       │░▒▓░│       ···[pACKER iNFO]···       │║
 ║│                                 │░▒▓░│                                 │║
 ║│  aUTHOR    : r!sc & DAEMON      │░▒▓░│  aUTHOR    : The Egoiste        │║
 ║│  dATE      : 29. Sept. 2000     │░▒▓░│  dATE      : ???- sep.2000      │║
 ║│  sUPPORTS  : v0.41b...v0.42     │░▒▓░│  rLS tYPE  : Freeware?          │║
 ║│  fiLE tYPE : PE                 │░▒▓░│  rATiNG    : 50-60%             │║
 ║│                                 │░▒▓░│                                 │║
 ║╞══════════════════════════════─══╧════╧══─══════════════════════════════╡║
 ║│                        ┌──────────────────────┐                        │║
 ║│────────────────────────├───UNPACKER DETAILS───┤────────────────────────│║
 ║│                        └──────────────────────┘                        │║
 ║│                                                                        │║
 ║│  Unpacker is decrypting all sections in memory and unpacks the code    │║
 ║│  with aPlib and does some fixing like killing the telock section...    │║
 ║│  Afterwards the whole program gets written back to disk                │║
 ║│                                                                        │║
 ║│                                                                        │║
 ║╞════════════════════════════════════════════════════════════════════════╡║
 ║│                        ┌──────────────────────┐                        │║
 ║│────────────────────────├───PACKER DETAILS─────┤────────────────────────│║
 ║│                        └──────────────────────┘                        │║
 ║│                                                                        │║
 ║│                      Data compression        [X]                       │║
 ║│                      Relocation compression  [X]                       │║
 ║│                      PMode tricks            [.]                       │║
 ║│                      DRx tricks              [.]                       │║
 ║│                      INT1 tricks             [X]                       │║
 ║│                      Stack tricks            [.]                       │║
 ║│                      Dumping detection       [X]                       │║
 ║│                      Password protection     [.]                       │║
 ║│                      Memory crc checking     [.]                       │║
 ║│                      Import section handling [X]                       │║
 ║│                      Export section handling [.]                       │║
 ║│                      Reloc section handling  [X]                       │║
 ║│                      Polymorph encryption    [.]                       │║
 ║│                                                                        │║
 ║╞════════════════════════════════════════════════════════════════════════╡║
 ```
 
 ---
 
 ```
                           --------------------
                          --                  --
                        ---    tEunlock V1.0   ---
                          --                  --
                           --------------------
                      ...coded by r!sc and DAEMON...

              ... respect our work as we respect the work of ...
                           ... the Egoiste ...


 How to use it:
~~~~~~~~~~~~~~~
simply start tEunlock.exe and click on the file u want to decrypt (isn't that simple :-)


 Features:
~~~~~~~~~~
-Kills the Telock section & almost rebuilds resource section
-Support for the following versions v0.41b, v0.41c and v0.42

 Known Problems:
~~~~~~~~~~~~~~~~
-bug when unpacking loader32.exe's debug section.. this is an actual bug in telock(41c only?).. not my code, on the 4th byte, it gets the value 3daeh in eax, subs this from the destination (so esi -> 4000h bytes before the va to unpack into), then executes a repz movsb to copy 10h bytes.. in my code, esi -> 390000h .. in loader32, esi -> 480000h (while its unpacking the data at 484000h), bug was fixed by putting a buffer infront of my unpack_buffer to stop page faults

-this also affects the 'how many bytes unpacked' counter, it returns like, 1200h instead of 1473ECh, the counter is used in the pe rebuilder, for calculating raw size of unpacked section, so the odd file will have a section with the wrong raw size and garbage data inside it


 History:
~~~~~~~~~
- 02th Octob. 2000
- v1.0, first release. nothing to see here


 Greetz:
~~~~~~~~
DAEMONS: First of all to DUNJA! (most lovely girl in universe),Da Fixer,
         Ambijambi,Christoph Gabler,The EYE,Fireball,Harry,The Gunman,
         The Wizard,Ikari(C64),Fairlight!(C64),Beastie Boys(C64),Uno,
         DYCUS,KeNkaNiff,Zanti,Kai,Nina,Tina,Rob,Wackiman,The Dinohunter,
         Kopo,the Cûnnîng... (of course to mum and dad, hehe)
```
