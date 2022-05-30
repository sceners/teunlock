; r!sc's unpacker - mmmm
; for every hour spent staring @ my screen...

; 18th september, main code finished and working after about 90 minutes :)

; 21st september, support added for telock v0.42

; 21st september, trying to add a resource rebuilder..
; about 5hrs later :) resources rebuild! not 100% bug free yet.. 
;  (sometimes raw size of new resource section is bigger then its vsize..)

; 22nd september, fixed resource thingy and stuff


align 4

bytesrw dd  ?

data_ptr            dd  ?
section_ptr         dd  ?
new_mem_ptr         dd  ?
process_size        dd  ?
raw_offset_dd       dd  ?
a_counter           dd  ?
import_rva          dd  ?
rsrc_rva            dd  ?
rsrc_offset         dd  ?
rsrc_size           dd  ?
rsrc_flag           dd  ?
te_section          dd  ?
tmp_raw             dd  ?
b_counter           dd  ?
rva_debug           dd  ?
r_reloc             dd  ?
r_reloc_size        dd  ?

dirty_fix_for_telocks_bug   db  100000h dup (?)
big_dirty_buffer    db  0a00000h dup (?)   ; uhm

;memptr dd ?
;fsize dd ?


.code
whois db 'r!sc'

te_unpack:
    pushad
    mov     [rsrc_flag], 0
    
; do some stuff, grab some data    
    mov     ebx, [memptr]       ; ptr to packed file in memory
    add     ebx, [ebx+3ch]      ; ebx -> pe header
    movzx   ecx, word ptr [ebx+6]   ; pe header + 6 -> number of sections
    mov     edx, [ebx+50h]      ; pe header + 50h -> size_of_image
    mov     [process_size], edx
    mov     edx, [ebx+0a8h]
    mov     [rva_debug], edx
    xor     edx, edx
    mov     [ebx+0a8h], edx
    mov     [ebx+0ach], edx
    mov     edi, ebx
    add     ebx, 0f8h           ; pe header + 0f8h -> first section
    mov     [section_ptr], ebx  ; store a ptr to the pe sections...
    mov     [ebx+24h], 0e0000020h   ; update section flags for first section, so 'wdasm' will work
    dec     ecx
    mov     [sections], cl

    ;dec     ecx
    mov     eax, 28h        ; sections are 28h ..
    imul    ecx
    add     ebx, eax
    mov     [te_section], ebx

    mov     eax, [ebx+14h]  ; raw offset of last section..
    add     eax, [memptr]
    cmp     is_41b,1            ; check if its 41b
    jz      telock_41b
    cmp     [eax], 08DC08B66h   ; check its the te-lock section (telock 41c)
    jz      telock_41c
    cmp     [eax], 6600eec1h    ; telock 42
    jz      telock_42
    jmp     r_error
    
telock_42:
    mov     ebx, [eax+1052h]    ; grab import table rva
    mov     [edi+80h], ebx
    mov     ebx, [eax+106bh]    ; grab entrypoint
    mov     [edi+28h], ebx
    mov     ebx, [eax+1056h]    ; grab reloc rva
    mov     [r_reloc], ebx
    mov     [edi+0a0h], ebx
    mov     dword ptr [edi+0f4h], 0
    mov     ebx, [eax+105ah]    ; resource rva
    mov     [rsrc_rva], ebx
    mov     ebx, [eax+106fh]    ; offset in resource section to compressed data
    mov     [rsrc_offset], ebx
    mov     ebx, [eax+106fh+4]  ; size of the compressed data in resource section
    mov     [rsrc_size], ebx
    add     eax, 107fh          ; ptr to the unpack data array..
    jmp     got_info

telock_41b:
    mov     ebx, [eax+0a32h]    ; grab import table rva
    mov     [edi+80h], ebx
    mov     ebx, [eax+0a4bh]    ; grab entrypoint
    mov     [edi+28h], ebx
    mov     ebx, [eax+0a36h]    ; grab reloc rva
    mov     [r_reloc], ebx
    mov     [edi+0a0h], ebx
    mov     dword ptr [edi+0f4h], 0
    mov     ebx, [eax+0a3ah]    ; resource rva
    mov     [rsrc_rva], ebx
    mov     ebx, [eax+0a4fh]    ; offset in resource section to compressed data
    mov     [rsrc_offset], ebx
    mov     ebx, [eax+0a4fh+4]  ; size of the compressed data in resource section
    mov     [rsrc_size], ebx
    add     eax, 0a5fh          ; ptr to the unpack data array..
    jmp     got_info

telock_41c:
    mov     ebx, [eax+0fd2h]    ; grab import table rva
    mov     [edi+80h], ebx
    mov     ebx, [eax+0febh]    ; grab entrypoint
    mov     [edi+28h], ebx
    mov     ebx, [eax+0fd6h]    ; grab reloc rva
    mov     [r_reloc], ebx
    mov     [edi+0a0h], ebx
    mov     dword ptr [edi+0f4h], 0
    mov     ebx, [eax+0fdah]    ; resource rva
    mov     [rsrc_rva], ebx
    mov     ebx, [eax+0fefh]
    mov     [rsrc_offset], ebx
    mov     ebx, [eax+0fefh+4]
    mov     [rsrc_size], ebx
    add     eax, 0fffh

got_info:
    mov     [data_ptr], eax ; ptr to unpack data . dd rva, dd sizeof_compressed_data

; allocate some memory to rebuild the file, and copy the pe header into it..
    call    VirtualAlloc, 0, [process_size], 1000h, 4
    mov     [new_mem_ptr], eax
    test    eax, eax
    jz      r_error
    mov     esi, [section_ptr]
    mov     ecx, [esi+14h]
    mov     [raw_offset_dd], ecx
    mov     [a_counter], 0
    mov     edi, eax
    mov     esi, [memptr]
    repz    movsb
    
; now let the unpacking / rebuilding begin

unpack_main:
    mov     esi, [section_ptr]
    mov     eax, 28h
    imul    [a_counter]
    add     esi, eax
    push    esi
    mov     esi, [esi+0ch]
    mov     edi, [data_ptr]
    cmp     esi, [rsrc_rva]
    jz      unpack_resource
scan_4_info:
    cmp     [edi], esi
    jz      unpack_it
    add     edi, 08
    cmp     dword ptr [edi], 0
    jnz     scan_4_info
blah:
    mov     esi, [esp]
    mov     ecx, [esi+10h]  ; raw size
    mov     esi, [esi+14h]  ; raw offset
    add     esi, [memptr]   ; heh
    mov     edi, [new_mem_ptr]
    add     edi, [raw_offset_dd]
    repz movsb

; fix the pe header entry..
fix_new_peheader:
    pop     esi
    mov     edi, [new_mem_ptr]
    add     edi, [edi+3ch]
    mov     eax, 28h
    imul    [a_counter]
    add     edi, 0f8h
    add     edi, eax
    mov     eax, [esi]      ; name
    mov     [edi], eax
    mov     eax, [esi+4]    ; name+4
    mov     [edi+4], eax
    mov     eax, [esi+8]    ; vsize
    mov     [edi+8], eax
    mov     eax, [esi+0ch]  ; rva
    mov     [edi+0ch], eax
    
    cmp     eax, [r_reloc]
    jnz     its_not_reloc_section
        mov     eax, [esi+10h]  ; raw size
        mov     [r_reloc_size], eax
        mov     [edi], 'ler.'                   ; db '.rel'
        mov     dword ptr [edi+4], 0000636fh    ; db 'oc',0,0

 its_not_reloc_section:
    mov     eax, [raw_offset_dd]
    mov     [edi+14h], eax  ; raw offset
    mov     eax, [esi+10h]  ; raw size
    add     [raw_offset_dd], eax
    mov     [edi+10h], eax

check_if_last_section:
    inc     [a_counter]
    movzx   ecx, byte ptr [sections]
    cmp     [a_counter], ecx
    jz      r_finished
    jmp     unpack_main
    ; im so dizzy, my head is spinning .
    
data_unpacked:
; this is the exit part of 'unpack_it:'
; need to compute the raw size of the unpacked data, then move it somewhere...

    lea     edi, big_dirty_buffer
    add     edi, eax
    mov     ecx, eax
scan_4_end:
    cmp     byte ptr [edi-1], 0
    jnz     found_end
    dec     edi
    dec     ecx
    jnz     scan_4_end
found_end:
    sub     edi, offset big_dirty_buffer

    mov     eax, edi
    mov     ecx, 200h
    xor     edx, edx
    idiv    ecx                 ; div 200h
    mov     eax, edx            ; put remainder into eax
    test    eax, eax            ; check remainder for 0
    jnz section_isnt_aligned    ;
    sub     ecx, ecx            ; we dont want to sub 0, 200h
section_isnt_aligned:
    sub     ecx, eax            ; calculate 200h-remainder
    add     ecx, edi            ; add raw size to result, now its aligned to 200h bytes

    cmp     [rsrc_flag], 1
    jnz     skip_rb_rsrc
    call    rebuild_resource
    mov     eax, ecx
    jmp     data_unpacked
skip_rb_rsrc:
    mov     edx, ecx    ; make copy of the counter
    mov     esi, [esp]
    mov     [esi+10h], ecx
    lea     esi, big_dirty_buffer
    mov     edi, [new_mem_ptr]
    add     edi, [raw_offset_dd]
    repz movsb
    ; dont cry, dont say a word

    xor     eax, eax
    mov     ecx, edx
    lea     edi, big_dirty_buffer
    repz    stosb  ; clear the buffer
    jmp     fix_new_peheader


unpack_it:

    mov     esi, [esp]  ; esi -> section header
    mov     eax, edi

; find this sections raw offset that we are going to unpack..
; so we can add imagebase(memptr) to it and pass this to the unpack proc

get_sections_raw_offset:
    add     dword ptr [data_ptr], 8
    mov     ebx, [esi+14h]  ; raw offset
    add     ebx, [memptr]
    mov     eax, [eax+4]    ; size of data to unpack
    test    eax, 80000000h
    jz      blah            ; if the highest bit isnt set, dont unpack it..
    and     eax, 7fffffffh
    ; cant stop thinking about you

    push    ebx
    push    eax
    call    sub_7105AE      ; unpack section into big_dirty_buffer,
                            ; returns eax -> size of unpacked data
    jmp     data_unpacked

;-----------------------
; all unpacking and rebuilding is finished (almost)

r_finished:
    mov     edi, [new_mem_ptr]
    add     edi, [edi+3ch]
    dec     word ptr [edi+6]    ; kill telock section
    mov     ecx, [r_reloc]
    mov     [edi+0a0h], ecx     ; update reloc info in data directory
    mov     ecx, [r_reloc_size]
    mov     [edi+0a4h], ecx     ; jaja

    mov     eax, 28h
    imul    word ptr [edi+6]
    push    edi ; save ptr to pe header
    add     edi, eax    ; eax -> size of sections
    add     edi, 108h   ; size of optional header + 10h
    and     di, 0fff0h  ; round it off to the nearest 10h
    mov     ecx, tag_size
    lea     esi, tag
    repz movsb          ; tag it :)
    pop     edi         ; restore ptr to pe header
    
    add     eax, edi
    add     eax, 0f8h-28h   ; eax -> last section
    mov     ebx, [eax+8]    ; vsize
    add     ebx, [eax+0ch]  ; rva
    mov     [edi+50h], ebx  ; update new process size

    lea     esi, file+200h
x2:
    dec     esi
    cmp     byte ptr [esi], '\'
    jnz     x2
    
    mov     byte ptr [esi], '!'
    push    esi

    call    CreateFileA, esi, 40000000h, 0, 0, 2, 80h, 0
    pop     esi
    mov     byte ptr [esi], '\'

    call    WriteFile, eax, [new_mem_ptr], [raw_offset_dd], offset bytesrw, 0, eax
    call    CloseHandle
    ; follow the sun

    call    VirtualFree, [new_mem_ptr], [process_size], 8000h


    mov eax, [memptr]
    popad
    ret


;------------------------------

unpack_resource:
;    int 3
    cmp     [rsrc_offset], 0    ; offset in rsrc section to compressed data
    jz      blah
    cmp     [rsrc_size], 0      ; size of compressed data in rsrc section..
    jz      blah
    mov     [rsrc_flag], 1      ; set this flag so rebuilder knows we have to rebuild the resources
    mov     esi, [esp]
    mov     ebx, [esi+14h]  ; raw offset
    add     ebx, [memptr]
    add     ebx, [rsrc_offset]
    mov     eax, [rsrc_size]
    ; magic carpet - stealth
    push    ebx
    push    eax
    mov     ecx, 12345678   ; marker so unpack algo knows its resources..
    call    sub_7105AE      ; unpack section into big_dirty_buffer + offset [rsrc_offset]
    
    mov     ecx, [rsrc_offset]
    add     eax, ecx
    mov     esi, [esp]
    mov     esi, [esi+14h]
    add     esi, [memptr]
    lea     edi, big_dirty_buffer
    repz    movsb           ; copy the non packed resources into the beginning of the big_buffer
    jmp     data_unpacked
; 
;------------------------------

rebuild_resource:
    mov     esi, [esp+4]
    pushad
    mov     [rsrc_flag], 0
    mov     [tmp_raw], ecx  ; aligned raw size of resource section..
    mov     edx, [esi+14h]  ; raw offset of rsrc section
    add     edx, [memptr]   ; edx -> resource tree
    movzx   ecx, word ptr [edx+0eh] ; edx -> IMAGE_RESOURCE_DIRECTORY (+0eh -> NumberOfIdEntries)
    add     cx, word ptr [edx+0ch]
    lea     eax, [edx+10h]  ; struct is 10h, so eax now points to the id entries
scan4something:
; 32 bits id + 32 bits offset to the data or offset to the next sub-directory.
    cmp     dword ptr [eax], 03 ; 03, icon
    jz      found_resource
    cmp     dword ptr [eax], 0eh ; 14, group icon
    jz      found_resource
    cmp     dword ptr [eax], 10h    ; 16, version info
    jz      found_resource
return_point:
    add     eax, 8
    dec     ecx
    jnz     scan4something
    
; fix vsize of rdata, incase the new raw size is bigger, quick hack..
    mov     eax, [tmp_raw]
    mov     ecx, 1000h
    xor     edx, edx
    idiv    ecx                 ; div 200h
    mov     eax, edx            ; put remainder into eax
    test    eax, eax            ; check remainder for 0
    jnz vsize_isnt_aligned      ;
    sub     ecx, ecx            ; we dont want to sub 0, 1000h
vsize_isnt_aligned:
    sub     ecx, eax            ; calculate 1000h-remainder
    add     [tmp_raw], ecx      ; add raw size to result, now its aligned to 1000h bytes

;+++++++++++++
; this bit updates the rva of reloc info, if its the section after resource..
; (would be much easier fully rebuilding the resource section so it didnt get any bigger)

    popad
    pushad
    mov ecx, [tmp_raw]
    mov [esi+8], ecx
    mov [esi], 'rsr.'
    mov dword ptr [esi+4], 63h
    push ecx
    mov ecx, [esi+0ch+28h]
    cmp dword ptr [r_reloc], 0
    jz just_update_next_section
    cmp ecx, [r_reloc]
    jz mess_with_reloc
just_update_next_section:
    mov ecx, [esp]
    add ecx, [esi+0ch]
    mov [esi+0ch+28h], ecx ; update next sections rva (
    pop ecx
    popad
    mov ecx, [tmp_raw]
    ret

mess_with_reloc:
    mov     edi, [data_ptr]
find_reloc_data:
    cmp     [edi], ecx
    jz      got_reloc_data
    add     edi, 8
    jmp     find_reloc_data
got_reloc_data:
    mov     ecx, [esp]
    add     ecx, [esi+0ch]
    mov     [esi+0ch+28h], ecx  ; update reloc sections rva (
    mov     [r_reloc], ecx      ; save new rva ..
    mov     [edi], ecx          ; update unpack data with new rva for reloc
    pop     ecx
    popad
    mov ecx, [tmp_raw]
    ret

; what a mess :/
;++++++++++++++++
;------------------------

found_resource:
    pushad
    mov     [b_counter], 0
    
    r_main_loop:
    mov     eax, [eax+4]
    test    eax, 80000000h  ; if the highest bit is set, the offset points to another IMAGE_RESOURCE_DIRECTORY
    jz      final_pointer
    and     eax, 7fffffffh
    lea     eax, [eax+edx]
    movzx   ebx, word ptr [eax+0eh] ; how many branches :o)
    add     bx, word ptr [eax+0ch]

    add     eax, 10h
d1:
    dec     ebx
    js      finished_last_branch
    pushad
    lea     eax, [ebx*8+eax]
    inc     dword ptr [b_counter]
    jmp     r_main_loop

finished_last_branch:
    cmp     dword ptr [b_counter], 0
    jz      ok_time_to_loop
    popad
    dec dword ptr [b_counter]
    jmp d1
ok_time_to_loop:
    popad
    jmp return_point

final_pointer:
    push    eax
    lea     eax, [eax+edx]
    push    eax
    mov     ecx, [eax+4]    ; size of resource
    mov     eax, [eax]      ; rva of resource
    
    mov     ebx, [te_section]
    sub     eax, [ebx+0ch]  ; sub rva of te_section off rva of this resource
    js      fuckoff_and_die ; if the result is signed, heh, resource isnt in the te_section..
    ; else, we will have the raw offset from the beginning of the te_section for the resource
    mov     esi, [ebx+14h]  ; get raw offset to section
    add     esi, [memptr]   ; add 'imagebase' :)
    add     esi, eax        ; add offset to resource
    
    lea     edi, big_dirty_buffer
    add     edi, [tmp_raw]
    repz    movsb
    mov     eax, [tmp_raw]
    add     eax, [rsrc_rva]
    pop     ebx
    pop     ebx
    add     ebx, offset big_dirty_buffer
    mov     [ebx], eax      ; update rva to resource
    mov     eax, [ebx+4]
    add     [tmp_raw], eax  ; update new raw offset to empty thingy
    
    popad
    dec dword ptr [b_counter]
    jmp d1
    
fuckoff_and_die:
    pop     ebx
    pop     ebx
    popad
    dec dword ptr [b_counter]
    jmp d1


;------------------------------
r_error:
    int 3   ; maybe there should be some sort of message here instead of a debug interrupt
    jmp $-2
;------------------------------



loc_71076B:
    ; unpacking of section finished...
    pop ebp
    pop edx
    sub edi, offset big_dirty_buffer
    mov [esp+1Ch], edi
    popad
    ret    8
    ; ...
    

; unpacker code ripped by ida, and junk code removed by hmm, me...

sub_7105AE:

var_8       = dword ptr -8
arg_0       = dword ptr  4

        pushad
        mov edx, ebx
        mov ebx, [esp+20h+arg_0]
        mov esi, [esp+30h+var_8]
        lea edi, big_dirty_buffer

        cmp ecx, 12345678
        jnz not_rsrc
        add edi, [rsrc_offset]
not_rsrc:

        push    edx
        push    ebp
        cld
        mov dl, 80h
loc_71063B:
        movsb
loc_71063F:             ; CODE XREF: sub_7105AE+F3j
        call    sub_710742
        jnb  loc_71063B
        xor ecx, ecx
        call    sub_710742
        jnb  loc_7106A6
        xor eax, eax
        call    sub_710742
        jnb  loc_7106C1
        inc ecx
        mov al, 10h
loc_71067C:             ; CODE XREF: sub_7105AE+DFj
        call    sub_710742
        adc al, al
        jnb  loc_71067C
        jnz loc_710723
        stosb
        jmp  loc_71063F

loc_7106A6:             ; CODE XREF: sub_7105AE+F5j
        call    sub_71075B
        dec ecx
        loop    loc_7106DF
        call    sub_710759
        jmp loc_710721

loc_7106C1:             ; CODE XREF: sub_7105AE+C2j
        lodsb
        shr eax, 1
        jz  loc_71076B
        adc ecx, ecx
        jmp loc_71071E

loc_7106DF:             ; CODE XREF: sub_7105AE+104j
        xchg    eax, ecx
        dec eax
        shl eax, 8
        lodsb
        call    sub_710759
        cmp eax, 7D00h
        jnb loc_71071E
        cmp ah, 5
        jnb loc_71071F
        cmp eax, 7Fh
        ja  loc_710720
loc_71071E:             ; CODE XREF: sub_7105AE+12Fj
        inc ecx
loc_71071F:             ; CODE XREF: sub_7105AE+162j
        inc ecx
loc_710720:             ; CODE XREF: sub_7105AE+16Ej
        xchg    eax, ebp
loc_710721:             ; CODE XREF: sub_7105AE+111j
        mov eax, ebp
loc_710723:             ; CODE XREF: sub_7105AE+E4j
        push    esi
        mov esi, edi
        sub esi, eax
        repe movsb
        pop esi
        jmp loc_71063F
;-----

sub_710742:
        add dl, dl
        jnz locret_710758
        mov dl, [esi]
        inc esi
        adc dl, dl
locret_710758:
        ret

sub_710759:
        xor ecx, ecx
sub_71075B:
        inc ecx
loc_71075C:
        call    sub_710742
        adc ecx, ecx
        call    sub_710742
        jb   loc_71075C
        ret

tag db 'unpacked by r!sc & decrypted by      DAEMON     '
tag_size = $-tag
