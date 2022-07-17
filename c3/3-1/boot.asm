    org     0x7c00          ;起始地址
;--------------------------------------
;init reg(include sp)
BaseOfStack equ 0x7c00
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
    jmp $
;----------------------------------------
;data
StartBootMessage: db 'Start Boot.'
TheEndOfMessage:

;----------------------------------------
;fill zero
    times 510 - ($ - $$) db 0
    dw 0xaa55





