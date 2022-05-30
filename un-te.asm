; decrypter by daemon
;
; no history...
;
; debugging telocked files was quite funny @ first :)
;
; coded under muzik : Ben Sims   - live @ mental      -_-_-_-_-_-_-_-_-_-_
;                     Sven V„th  - live @ ????        -_-_-_-_-_-_-_-_-_-_-_
;                     Adam Beyer - live @ turned on   -_-_-_-_-_-_-_-_-_-_-_-_
.386P
Locals
jumps
.Model Flat ,StdCall


mb_ok                   equ 0
hWnd                    equ 0
FILE_ATTRIBUTE_NORMAL   equ 080h
OPEN_EXISTING           equ 3
GENERIC_READ            equ 80000000h
GENERIC_WRITE           equ 40000000h


extrn ExitProcess      :PROC ;procedure to end the program
extrn MessageBoxA      :PROC ;procedure to show a MessageBox
extrn CreateFileA      :PROC ;   " ...  to open a file
extrn ReadFile         :PROC ;read a block of a file
extrn WriteFile        :PROC ;write a block into a file 
extrn CloseHandle      :PROC ;close file
extrn GetFileSize      :PROC ;get the filesize
extrn GlobalAlloc      :PROC ;allocate memory
extrn GlobalFree       :PROC ;set (free) memory
extrn SetFilePointer   :PROC ;set the filepointer
extrn GetOpenFileNameA :PROC ;bla bla bla
extrn VirtualAlloc     :PROC
extrn VirtualFree      :PROC


.Data
ofn_struct  dd  04ch,0,0,ofn_filter,0,0,0   ; open file name struct
            dd  file
            dw  0200h,0
            dd  0,0,0,caption,01000h,0,0,0,0,0

ofn_filter  db  'telocked exe, dll or ocx',0,'*.exe;*.dll;*.ocx',0,0

caption  db " -= tEunlock v1.0 =- by r!sc and DAEMON in 2K",0
err_cap  db "FUCK IT!",0                           ;caption for errormessage
openerr  db "Unable to open file",13,10,0          ;errortext opening file
memerr   db "Cannot allocate memory",0             ;errortext alloc. memory
wrong    db 10,13,"This file is not protected by tElock!",0

decrypte    db "job done, decrypted & unpacked "
file        db  200h dup (?)

sections    db  ?                ; sections of pefile
fhandle     dd  ?                ;variable for the filehandle
fsize       dd  ?                ;variable for the filesize
memptr      dd  ?                ;pointer to allocated memory
bread       dd  ?                ;number of read bytes

DECRYPT_KEY dd  ?                ; saving the decryption key!
PE_HEADER   dd  ?                ; store location of pe-header

is_41b      dd  ?                ; is it version 0.41b?
is_42       dd  ?                ; is it version 0.42?

FIRST_LAYER     DD 000000178h        ; valid for all versions yet
CALC_KEY_VALUE1 DD ?                 ;
vc              DD 000000E95h        ; this is for 0.41c
vb              DD 0000008F8h        ; this is for 0.41b
vd              DD 000000F16h        ; this is for 0.42
where_encrypted DD 000000063h        ; where is first layer (41b & 41c not 42)

hard_key        DD 0EDB88320h        ; valid for v0.41b and c not for 0.42
;....

;#! ;)
include te_unpack.asm
;-

;our code

.Code
Main:

        call GetOpenFileNameA, offset ofn_struct

        push 0                      ;for Win95 always 0
        push FILE_ATTRIBUTE_NORMAL  ;standard Fileattributes
        push OPEN_EXISTING          ;open existing file
        push 0                      ;no Security-attributes
        push 0                      ;disable Share-Mode
        push GENERIC_READ + GENERIC_WRITE   ;read- and writeaccess
        push offset file            ;offset of the filename
        Call CreateFileA            ;open file
        mov  fhandle,eax            ;save filehandle
        cmp  eax,0FFFFFFFFh         ;if eax=FFFFFFFF then 
                                    ;error
        jnz  file_is_here

        call MessageBoxA, 0, offset openerr, offset err_cap, 0
        jmp  end_                   ; exit after displaying fileio error

file_is_here:                                   ;file is there, so go on

        push 0
        push fhandle                            ;PUSH filehandle
        Call GetFileSize                        ;get the filesize
        mov  fsize,eax                          ;save the filesize

        push fsize                              ;PUSH filesize=size of the buffer
        push 0                                  ;0=GMEM_FIXED -> fixed memory-area
        Call GlobalAlloc                        ;allocate as much as memory as filesize 
        mov  memptr,eax                         ;save pointer to memory-area

        cmp  eax,0                              ;if eax=0, then there were errors
        jnz  mem_ok

        call MessageBoxA, 0, offset memerr, offset err_cap, 0
        jmp  end_kill_handle                    ;end program, close file b4

mem_ok:                                         ;memory is allocated -> next step

        push 0                                  ;set to 0 in most cases
        push offset bread                       ;pointer to number of read bytes
        push fsize                              ;read how many bytes?, 
                                                ;fsize=whole file
        push memptr                             ;save where? ->allocated memory
        push fhandle                            ;filehandle
        Call ReadFile                           ;read file!


        mov  edi,memptr                         ;set EDI to memory-area
      
        mov  edx,edi
        mov  esi,[edi+03ch]                     ;Locate our ! PEHEADER !
        add  edx,esi
        push edx
        mov  pe_header,edx
        mov  edx,[edx]
        cmp  edx,'EP'                           ; Check for PE ???
        jnz  end_kill_all                       ; No?  then quit

;===================================================================
; CHECK OUT LAST SECTION TO CHECK IF FILE IS PROTECTED
;===================================================================

        pop  edx

        mov  dl,byte ptr [edx+06h]              ; How many Sections do
        mov  byte ptr [sections],dl             ; we have ??? store it
                                                ; in sections
  
        xor  ecx,ecx                            ; Zero ecx
        mov  cl,byte ptr [sections]             ; put number of sections in cx
        sub  cl,01                              ; sub 1 from counter 
        mov  edx,edi                            ; put target offset into edx
        add  edx,esi
        add  edx,0F8h

;#!
        mov [section_ptr], edx
;-

get_sections_name:                              ; WE NEED THE LAST SECTION IN 
        add  edx,40                             ; THE FILE... SO GO AND HUNT FOR
        loop get_sections_name                  ; IT...


        mov  ebx,[edx+014h]                     ; ebx holds now p. offset

        mov  edi,memptr
        add  edi,ebx

        push edi

        cmp  [edi], 06600EEC1h                  ; is it telock v0.42?
        je   found_v042
        
        cmp  [edi],08DC08B66h                   ; check first 4 bytes
        jne  nope_we_dont                       ; not the same?

        cmp  [edi+04h],001EB2424h               ; check next 4 bytes
        jne  nope_we_dont                       ; not the same?
                                                ; i did 2 checks just to be
                                                ; really sure
        cmp  [edi+0b50h],06F6C4574h             ; is it telock v0.41b?
        je   found_v041b

        jmp  found_v041c

found_v041b:
        add     edi, 0a5fh
        mov     [data_ptr], edi
        
        mov     edi,vb
        mov     calc_key_value1,edi
        mov     is_41b,1
        jmp     we_are_so_so_happy

found_v041c:
        add     edi, 0fffh
        mov     [data_ptr], edi
        
        mov     edi,vc
        mov     calc_key_value1,edi

        jmp     we_are_so_so_happy

found_v042:
        add     edi,0107fh
        mov     [data_ptr], edi

        mov     first_layer,0179h       ; yes since v0.42 he changed it!

        mov     hard_key,0CDB792E1h     ; wow another change!
        add     where_encrypted,02h     ; should be 065h

        mov     is_42,1
        mov     edi,vd
        mov     calc_key_value1,edi

we_are_so_so_happy:
;===================================================================
; OKAY, ITS PROTECTED!
; SO WE CAN GO AND DECRYPT THE FIRST LAYER
; (we need it to calculate the decryption key!)
;===================================================================

        POP   EDI
        PUSH  EDI
        ADD   EDI, WHERE_ENCRYPTED             ; point edi to encrypted
                                               ; code in telock section

        MOV   ESI, EDI
        MOV   ECX, FIRST_LAYER 
        XOR   EAX, EAX

DECRYPT_LOOP2:

        LODSB
        XOR   AL,  CL
        STOSB
        LOOP  DECRYPT_LOOP2

;===================================================================
; CALCULATING THE DECRYPTION KEY + SETUP FOR NEXT SHIT
; (decryption key is based on so like crc)
;===================================================================

               POP   EDI
               PUSH  EDI
               MOV   ESI, EDI
               MOV   EBX, CALC_KEY_VALUE1
               XOR   ECX, ECX
               LEA   EDX, [ECX-01h]              ; EQUAL TO 0FFFFFFFFh

CALC_KEY_LOOP: XOR   EAX, EAX
               LODSB
               XOR   AL,  DL
INNER_LOOP1:   SHR   EAX, 01h
               JAE   SUCK1
               XOR   EAX, HARD_KEY               ; 0EDB88320h
SUCK1:         INC   ECX
               AND   CL,  07h
               JNZ   INNER_LOOP1
               SHR   EDX, 08h
               XOR   EDX, EAX
               DEC   EBX
               JG    CALC_KEY_LOOP
               POP   EDI
               PUSH  EDI

               cmp   is_42,1
               jne   dont_play_with_edi
               add   edi,081h

dont_play_with_edi:
               cmp   is_41b,1
               jne   reset_to_41c_value

               add   edi,08F8h
               jmp   dont_touch_it_anymore

reset_to_41c_value:
               add   edi,0E95h

dont_touch_it_anymore:
               XOR   DX,[EDI]                    ; MADE A MISTAKE AT FIRST!
                                                 ; THOUGHT THAT THIS VALUE IS
                                                 ; ALWAYS  00h.... ?!?
               POP   EDI
               MOV   DECRYPT_KEY,EDX

AND_AGAIN:
;              int 3
               mov  esi, [data_ptr]
               mov  edi, [section_ptr]
               add       [data_ptr], 8
               mov  eax, [esi]      ; rva of section to decrypt
               test eax, eax
               jz   ahhh_decrypted
               mov  ecx, [esi+4]    ; RAW size of section to decrypt
               and  ecx, 7fffffffh  ; clear highest bit :d (only used by the unpacker)

scan4section_rva:
               cmp  eax, [edi+0ch]  ; cmp rva_section_to_decrypt, [section.rva]
               jz   x_found_section
               add  edi, 28h
               jmp  scan4section_rva
x_found_section:
               mov  edi, [edi+14h]  ; grab raw offset
               add  edi, [memptr]   ; add pseudo imagebase
;-

;===================================================================
; DECRYPTION ROUTINE FOR ALL SECTIONS IN THE PE FILE
;===================================================================

               MOV   ESI, EDI                       ; SET ESI TO EDI...
               MOV   EBX, DECRYPT_KEY               ; VALUE USED FOR DECRYPTION
                                                    ; ecx is already set
               XOR   EAX, EAX

DECRYPT_LOOP:  LODSB
               SUB   AL,042H
               XOR   AL,CL
               MOV   BYTE PTR [EDI],AL
               ROR   AL,CL
               XOR   AL,BL
               ADD   BL,BYTE PTR [EDI]
               ADC   BL,CL
               TEST  CL,01
               JNZ   @CASE1

               SHR   EBX,00000001H
               TEST  EBX,00000002H
               JNZ   @CASE1

               ROL   EBX,CL
               LEA   EBX,[EBX*8+EBX]

@CASE1:        STOSB
               DEC   ECX
               JG    DECRYPT_LOOP

               JMP   AND_AGAIN

ahhh_decrypted:

;#! and this call added...
      call    te_unpack
;-


      call MessageBoxA, hWnd, offset decrypte, offset caption, mb_ok
      jmp  end_kill_all

nope_we_dont:
        call MessageBoxA, hWnd, offset wrong, offset caption, mb_ok
end_kill_all:
        push memptr                ;pointer to Memoryarea
        call GlobalFree            ;enable (free) memory
end_kill_handle:
        push fhandle               ;PUSH filehandle
        call CloseHandle           ;CloseHandle

end_:
        CALL    ExitProcess        ;Quit program

End Main                           ;end of code, JUMP-spot (main)
