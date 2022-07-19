    org             0x7c00
BaseOfStack         equ     0x7c00      ;栈地址
BaseOfLoader        equ     0x1000      ;loader加载的位置（段地址）1M以内有各种各样的东西所以放到1M以外
OffsetOfLoader      equ     0x0         ;偏移地址

RootDirSectors      equ     14          ;根目录占用的扇区数：BPB_RootEntCnt（根目录的目录项数）* 32（每一个目录项32字节） / 512 = 14
SectorNumOfRootDirStart     equ     19  ;根目录起始扇区：1（MBR） + 9（FAT扇区数）* 2（FAT个数） = 19
SectorNumOfFAT1Start        equ     1   ;FAT起始位置
SectorBalance               equ     17  


    jmp short       Label_Start  
    nop  
    BS_OEMName      db  'MINEboot'
    BPB_BytesPerSec dw  512
    BPB_SecPerClus  db  1
    BPB_RsvdSecCnt  dw  1
    BPB_NumFATs     db  2
    BPB_RootEntCnt  dw  224
    BPB_TotSec16    dw  2880
    BPB_Media       db  0xf0
    BPB_FATSz16     dw  9
    BPB_SecPerTrk   dw  18
    BPB_NumHeads    dw  2
    BPB_hiddSec     dd  0
    BPB_TotSec32    dd  0
    BS_DrvNum       db  0
    BS_Reserved1    db  0
    BS_BootSig      db  29h
    BS_VolID        dd  0
    BS_VolLab       db  'boot loader'
    BS_FileSysType  db  'FAT12   '


Label_Start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack
;---------------------------------------
;clear screen
    mov ax, 0600h          ;int 0x10中断中的6号为清屏
    mov bx, 0700h
    mov cx, 0
    mov dx, 184fh
    int 10h
;---------------------------------------
;set focus
    mov ax, 0200h         ;利用int0x10 set光标（0，0）  
    mov dx, 0000h
    mov bx, 0000h
    int 10h
;---------------------------------------
;display
    mov ax, 1301h         ;int0x10 显示字符串
    mov bx, 000fh
    mov cx, 11
    mov dx, 0000h
    
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 10h
;----------------------------------------
;reset floppy
    xor ah, ah
    xor dl, dl
    int 13h


;======================================
;search loader.bin
    mov word    [SectorNo],     SectorNumOfRootDirStart
Label_Search_In_Root_Dir_Begin:
    cmp word    [RootDirSizeForLoop],   0
    jz  Label_No_LoaderBin          ;如果到0说明没有找到
    
    dec word    [RootDirSizeForLoop]
    mov ax, 0000h
    mov es, ax
    mov bx, 8000h                   ;暂时放到这里进行处理（7E00应该也可以）
    mov ax, [SectorNo]              ;准备调用读取扇区的其他参数
    mov cl, 1
    call Func_ReadOneSector
    
    mov si, LoaderFileName
    mov di, 8000h
    mov dx, 10h                     ;16个（每个扇区能容乃的目录项个数）

Label_Search_For_LoaderBin:
    cmp dx, 0
    jz  Label_Goto_Next_Sector_In_Root_Dir  ;dx为0表明当前扇区没有找到，到下一个扇区继续寻找
    dec dx
    mov cx, 11                      ;目录项的前11字节为名称和扩展名
    
Label_Cmp_FileName:
    cmp cx, 0
    jz  Label_FileName_Found
    dec cx
    lodsb
    cmp al, byte    [es:di]
    jz  Label_Go_On
    jmp Label_Different

Label_Go_On:
    inc di                           ;si会自动加
    jmp Label_Cmp_FileName

Label_Different:
    and di, 0ffe0h
    add di, 20h
    mov si, LoaderFileName
    jmp Label_Search_For_LoaderBin


Label_Goto_Next_Sector_In_Root_Dir:
    add word    [SectorNo], 1
    jmp Label_Search_In_Root_Dir_Begin



;--------------------------------------------------
;display of no_loader.bin
Label_No_LoaderBin:
    mov ax, 1301h
    mov bx, 008ch
    mov cx, 21
    mov dx, 0100h
    push ax
    mov ax,  ds
    mov es, ax
    pop ax
    mov bp, NoLoaderMessage
    int 10h 
    jmp $
;--------------------------------------------------
;found loader.bin
Label_FileName_Found:
    and di, 0ffe0h
    add di, 1ah
    mov cx, word    [es:di]
    push cx
    mov ax, RootDirSectors
    add cx, ax
    add cx, SectorBalance           ;这里解释一下：根目录起始扇区号+根目录所占扇区（这里的根目录扇区号直接减了2）
                                    ;FAT表项值减2（FAT【0】【1】无效）
    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    mov ax, cx

Label_Go_On_Loading_File:

    push ax
    push bx
    mov ah, 0eh 
    mov al, '.'
    mov bl, 0fh 
    int 10h 
    pop bx
    pop ax

    mov cl, 1
    call Func_ReadOneSector     ;此时ax中为磁盘上loader.bin的数据区，es：bx指向loader内存中存放的位置0x10000
    pop ax                      ;pop出为起始簇通过查看boot.img知道为3
    call Func_GetFATEntry
    cmp ax, 0fffh               ;0fffh为结束的标志
    jz  Label_File_Loaded

    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BPB_BytesPerSec]
    jmp Label_Go_On_Loading_File

Label_File_Loaded:
    jmp BaseOfLoader:OffsetOfLoader



Func_GetFATEntry:
    push es
    push bx

    push ax
    mov ax, 00
    mov es, ax
    pop ax

    mov byte [Odd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    cmp dx, 0
    jz  Label_Even          ;判断奇偶
    mov byte [Odd], 1
Label_Even:
    xor dx, dx
    mov bx, [BPB_BytesPerSec]
    div bx                  ;ax中为偏移扇区号dx为扇区中的偏移地址
  
    push dx
    mov bx, 8000h
    add ax, SectorNumOfFAT1Start
    mov cl, 2
    call Func_ReadOneSector
    pop dx

    add bx, dx
    mov ax, [es:bx]
    cmp byte [Odd], 1
    jnz Label_Even_2
    shr ax, 4

Label_Even_2:
    and ax, 0fffh
    pop bx
    pop es
    ret







;------------------------------------------
;read one sector from floppy
;               para:AX BeginSector     CL NumOfSec  ES:BX 
Func_ReadOneSector:
    push    bp 
    mov     bp, sp 
    sub     esp, 2
    mov     byte [bp - 2], cl
    push    bx
    mov     bl, [BPB_SecPerTrk]
    div     bl
    inc     ah
    mov     cl, ah
    mov     dh, al
    shr     al, 1
    mov     ch, al 
    and     dh, 1
    pop     bx
    mov     dl, [BS_DrvNum]
Label_Go_On_Reading:
    mov     ah, 2
    mov     al, byte [bp - 2]
    int     13h
    jc      Label_Go_On_Reading
    add     esp, 2
    pop     bp
    ret 


;-------------------------------
;tmp data
RootDirSizeForLoop  dw  RootDirSectors
SectorNo            dw  0
Odd                 db  0
;---------------------------------
;display messages
StartBootMessage:   db  "Start Boot."
NoLoaderMessage:    db  "ERROR:No LOADER Found"
LoaderFileName:     db  "LOADER  BIN",0
;--------------------------------------
;fill zero
    times 510 - ($ - $$) db 0
    dw 0xaa55