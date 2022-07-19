org         10000h
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0
    mov ss, ax
    mov sp, 0x7c00

;---------------------------------------
;display
    mov ax, 1301h         ;int0x10 显示字符串
    mov bx, 000fh
    mov cx, 12
    mov dx, 0200h
    mov bp, StartLoaderMessage
    int 10h

    jmp $


StartLoaderMessage:
    db  "Start Loader"