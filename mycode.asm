; ==========================================================
; 8086 Assembly - OPTIMUM SERIT, HIZLI MANEVRA YAPAN ARAC
; Kontroller: 'A' (Sola), 'D' (Saga)
; ==========================================================

.model small
.stack 100h

; ----------------------------------------------------------
; VERI BOLUMU: Oyunun degiskenleri burada tutulur.
; ----------------------------------------------------------
.data
    oyun_hizi      dw 800    ; Oyunun dongu gecikmesi (Azaldikca hizlanir)
    min_hiz        dw 400    ; Ulasilabilecek maksimum hiz
    hiz_sayaci     db 0      ; Hizlandirma periyodunu tutar
    
    skor           dw 0      ; Oyuncunun ana skoru
    skor_gecikme   db 0      ; Skorun yavas yavas artmasini saglayan sayac
    
    serit_x        db 28, 40, 52  ; Sol, Orta ve Sag seritlerin X merkezleri
    
    oyuncu_x       db 40     ; Sari aracin baslangic X koordinati
    oyuncu_y       db 19     ; Sari aracin baslangic Y koordinati
    
    engel1_x       db 28     ; 1. Kirmizi aracin X koordinati
    engel1_y       db 0      ; 1. Kirmizi aracin Y koordinati
    
    engel2_x       db 52     ; 2. Kirmizi aracin X koordinati
    engel2_y       db -12    ; 2. Kirmizi aracin Y koordinati (Gecikmeli girer)

    rastgele_tohum db 0
    msg_bitti      db 'OYUN BITTI! Skorunuz: $'
    msg_cikis      db 13, 10, 'Cikmak icin bir tusa bas... $'

.code
ana proc
    mov ax, @data
    mov ds, ax

    ; Video modunu 80x25 renkli metin modu (03h) olarak ayarla ve imleci gizle.
    mov ax, 0003h
    int 10h
    mov ah, 01h
    mov cx, 2607h
    int 10h

; ----------------------------------------------------------
; OYUN DONGUSU: Oyun bitene kadar saniyede onlarca kez calisan ana blok.
; Sirasiyla: Ekrani sil, pozisyonlari guncelle, ekrana ciz, carpismayi kontrol et.
; ----------------------------------------------------------
OyunDongusu:
    ; 1) Eski arac cizimlerini ekrandan temizle
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    call ArabaSilVRAM
    mov dl, engel1_x
    mov dh, engel1_y
    call ArabaSilVRAM
    mov dl, engel2_x
    mov dh, engel2_y
    call ArabaSilVRAM

    ; 2) Girdileri oku ve dusmanlari asagi kaydir
    call GirdiKontrolPort60h
    call EngelleriGuncelle

    ; 3) Arkaplani, araclari ve UI'yi (Skor/Hiz) yeni pozisyonlarinda ciz
    call YolCizVRAM
    call HizCizVRAM     
    call SkorCizVRAM    
    
    mov dl, engel1_x
    mov dh, engel1_y
    mov bl, 0Ch         ; Dusman Rengi: Kirmizi
    call ArabaCizVRAM
    
    mov dl, engel2_x
    mov dh, engel2_y
    mov bl, 0Ch         ; Dusman Rengi: Kirmizi
    call ArabaCizVRAM
    
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, 0Eh         ; Oyuncu Rengi: Sari
    call ArabaCizVRAM

    ; 4) Carpisma kontrolu yap ve CPU'yu beklet (Oyun hizi icin)
    call CarpismaKontrol
    call OzelGecikme
    
    ; Skor artis mekanizmasi (Her 4 karede 1 puan)
    inc skor_gecikme
    cmp skor_gecikme, 4
    jl HizGuncellemeyeGec
    mov skor_gecikme, 0
    inc skor

HizGuncellemeyeGec:
    ; Zaman gectikce oyunu hizlandir (gecikmeyi azalt)
    inc hiz_sayaci
    cmp hiz_sayaci, 20      
    jl DonguyeDon
    mov hiz_sayaci, 0        
    mov ax, oyun_hizi
    cmp ax, min_hiz        
    jle DonguyeDon          
    sub oyun_hizi, 10        

DonguyeDon:
    jmp OyunDongusu
ana endp

; ==========================================================
; FONKSIYONLAR
; ==========================================================

; ----------------------------------------------------------
; HizCizVRAM: Sag ust koseye mevcut hizi hesaplayip ekrana yazar.
; ----------------------------------------------------------
HizCizVRAM proc
    mov ax, 0B800h    ; Ekranin VRAM baslangic adresi
    mov es, ax
    
    mov di, 130       ; Sag ust kose koordinati
    mov ah, 0Fh       ; Renk: Parlak Beyaz
    mov al, 'H'
    mov es:[di], ax
    mov al, 'I'
    mov es:[di+2], ax
    mov al, 'Z'
    mov es:[di+4], ax
    mov al, ':'
    mov es:[di+6], ax

    ; Matematiksel olarak hizi (km/h) hesaplama
    mov ax, 800
    sub ax, oyun_hizi
    shr ax, 3       
    add ax, 50      
    
    ; Sayiyi 10'a bolerek basamaklarina ayirma ve cizme islemi
    mov bl, 10
    div bl          
    mov dl, ah      
    xor ah, ah      
    div bl          
    mov ch, al      
    mov cl, ah      

    mov al, ch
    add al, '0'
    mov ah, 0Fh     
    cmp al, '0'
    jne YuzlerYaz
    mov al, ' '     
YuzlerYaz:
    mov es:[di+10], ax
    mov al, cl
    add al, '0'
    mov ah, 0Fh     
    mov es:[di+12], ax
    mov al, dl
    add al, '0'
    mov ah, 0Fh     
    mov es:[di+14], ax
    ret
HizCizVRAM endp

; ----------------------------------------------------------
; SkorCizVRAM: Hiz bilgisinin altina puani VRAM uzerinden yazar.
; ----------------------------------------------------------
SkorCizVRAM proc
    mov ax, 0B800h
    mov es, ax
    
    mov di, 290       ; Hizin bir satir alti
    mov ah, 0Fh
    mov al, 'S'
    mov es:[di], ax
    mov al, 'K'
    mov es:[di+2], ax
    mov al, 'O'
    mov es:[di+4], ax
    mov al, 'R'
    mov es:[di+6], ax
    mov al, ':'
    mov es:[di+8], ax

    mov ax, skor
    mov bx, 10
    mov cx, 4
SkorBasamaklaraAyir:
    xor dx, dx
    div bx
    push dx           ; Yigina (Stack) atarak ters cevirme mantigi
    loop SkorBasamaklaraAyir

    mov cx, 4
    add di, 10      
SkoruEkranaBas:
    pop dx
    mov al, dl
    add al, '0'
    mov ah, 0Fh
    mov es:[di], ax 
    add di, 2       
    loop SkoruEkranaBas
    ret
SkorCizVRAM endp

; ----------------------------------------------------------
; YolCizVRAM: 4 adet dikey cizgi cekerek seritleri olusturur.
; ----------------------------------------------------------
YolCizVRAM proc
    mov ax, 0B800h
    mov es, ax
    mov di, 0
    mov cx, 25        ; 25 satir boyunca tekrarla
YolDongusu:
    mov ax, 0F7Ch     ; '|' karakteri
    mov es:[di + 44], ax   
    mov es:[di + 68], ax   
    mov es:[di + 92], ax  
    mov es:[di + 116], ax  
    add di, 160       ; Sonraki satira gec     
    loop YolDongusu
    ret
YolCizVRAM endp

; ----------------------------------------------------------
; ArabaCizVRAM: (DL, DH) koordinatina BL renginde 7x5 arac cizer.
; ----------------------------------------------------------
ArabaCizVRAM proc
    push ax
    push cx
    push dx
    push di
    push es
    cmp dh, 0
    jl CizimiAtla      
    cmp dh, 20          
    jg CizimiAtla      
    
    ; VRAM Ofset Hesaplama Formulu: (Y * 80 + X) * 2
    mov ax, 0B800h
    mov es, ax
    mov al, 80
    mul dh
    mov ch, 0
    mov cl, dl
    add ax, cx
    shl ax, 1
    mov di, ax
    sub di, 6           
    
    mov ah, bl          ; Parametreyle gelen rengi kullan
    
    ; Aracin dis hatlari ve tamponlari ASCII karakterleriyle yazilir
    mov al, '['
    mov es:[di], ax
    mov al, '-'
    mov es:[di+2], ax
    mov es:[di+4], ax
    mov al, '^'
    mov es:[di+6], ax
    mov al, '-'
    mov es:[di+8], ax
    mov es:[di+10], ax
    mov al, ']'
    mov es:[di+12], ax

    mov al, '|'
    mov es:[di+160], ax
    mov es:[di+172], ax
    mov es:[di+320], ax
    mov es:[di+332], ax
    mov es:[di+480], ax
    mov es:[di+492], ax

    mov al, '['
    mov es:[di+640], ax
    mov al, '='
    mov es:[di+642], ax
    mov es:[di+644], ax
    mov es:[di+646], ax
    mov es:[di+648], ax
    mov es:[di+650], ax
    mov al, ']'
    mov es:[di+652], ax

CizimiAtla:
    pop es
    pop di
    pop dx
    pop cx
    pop ax
    ret
ArabaCizVRAM endp

; ----------------------------------------------------------
; ArabaSilVRAM: Aracin hareket ettigi onceki pozisyonunu siler.
; ----------------------------------------------------------
ArabaSilVRAM proc
    push ax
    push cx
    push dx
    push di
    push es
    cmp dh, 0
    jl SilmeyiAtla
    cmp dh, 20
    jg SilmeyiAtla
    
    mov ax, 0B800h
    mov es, ax
    mov al, 80
    mul dh
    mov ch, 0
    mov cl, dl
    add ax, cx
    shl ax, 1
    mov di, ax
    sub di, 6           
    
    mov cx, 5           ; 5 satir boyunca silecek dongu
    mov ax, 0720h       ; Siyah bosluk karakteri
SatirSil:
    mov es:[di], ax
    mov es:[di+2], ax
    mov es:[di+4], ax
    mov es:[di+6], ax
    mov es:[di+8], ax
    mov es:[di+10], ax
    mov es:[di+12], ax
    add di, 160         
    loop SatirSil

SilmeyiAtla:
    pop es
    pop di
    pop dx
    pop cx
    pop ax
    ret
ArabaSilVRAM endp

; ----------------------------------------------------------
; GirdiKontrolPort60h: Donanimdan tusa basilip basilmadigini okur.
; A ve D tuslari ile serit manevrasi yapar (2 birim atlama ile).
; ----------------------------------------------------------
GirdiKontrolPort60h proc
    in al, 60h          ; Klavye donanim portunu oku
    cmp al, 1Eh         ; 'A' tusu mu?
    je SolaGit
    cmp al, 20h         ; 'D' tusu mu?
    je SagaGit
    cmp al, 10h         ; 'Q' tusu mu? (Cikis)
    je CikisYap
    ret                 
SolaGit:
    cmp oyuncu_x, 26    ; Sinirlar kontrol edilir
    jle GirdiTamam
    sub oyuncu_x, 2     ; Hýzlý manevra (2 birim sola)
    cmp oyuncu_x, 26    
    jge GirdiTamam
    mov oyuncu_x, 26    ; Sinir disina ciktiginda sinira sabitle
    ret
SagaGit:
    cmp oyuncu_x, 54    
    jge GirdiTamam
    add oyuncu_x, 2     ; Hýzlý manevra (2 birim saga)
    cmp oyuncu_x, 54    
    jle GirdiTamam
    mov oyuncu_x, 54    
    ret
CikisYap:
    mov ax, 0003h
    int 10h
    mov ah, 4ch
    int 21h
GirdiTamam:
    ret
GirdiKontrolPort60h endp

; ----------------------------------------------------------
; EngelleriGuncelle: Dusman araclarini Y ekseninde +1 kaydirir.
; Ekranin altina ulasan araci rastgele yeni bir seritten uste atar.
; ----------------------------------------------------------
EngelleriGuncelle proc
    inc engel1_y
    cmp engel1_y, 21    
    jl Engel2Guncelle
    mov engel1_y, 0
    call RastgeleXAl
    mov engel1_x, al
Engel2Guncelle:
    inc engel2_y
    cmp engel2_y, 21
    jl EngellerTamam
    mov engel2_y, 0
    call RastgeleXAl
    mov engel2_x, al
EngellerTamam:
    ret
EngelleriGuncelle endp

; ----------------------------------------------------------
; CarpismaKontrol: Oyuncu ile dusmanlar arasinda hitbox kontrolu.
; Eger bir carpisma tespit edilirse OyunBitti etiketine atlar.
; ----------------------------------------------------------
CarpismaKontrol proc
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, engel1_x
    mov bh, engel1_y
    call CarpismaKutusu
    cmp al, 1
    je OyunBitti
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, engel2_x
    mov bh, engel2_y
    call CarpismaKutusu
    cmp al, 1
    je OyunBitti
    ret

OyunBitti:
    ; Oyun bittiginde ekrani temizler, Skoru DOS uzerinden yazdirir.
    mov ax, 0003h
    int 10h
    mov ah, 02h
    mov dx, 0A19h       
    mov bh, 0
    int 10h
    mov ah, 09h
    lea dx, msg_bitti
    int 21h
    call SkorYazDOS
    mov ah, 09h
    lea dx, msg_cikis
    int 21h
    
    ; Bir muddet bekleme suresi saglar (yanlislikla kapanmamasi icin)
    mov ah, 86h
    mov cx, 000Fh       
    mov dx, 4240h
    int 15h
TamponTemizle:
    mov ah, 01h
    int 16h
    jz TusaBasildi
    mov ah, 00h
    int 16h
    jmp TamponTemizle
TusaBasildi:
    mov ah, 00h
    int 16h
    mov ax, 0003h       
    int 10h
    mov ah, 4ch         
    int 21h
CarpismaKontrol endp

; ----------------------------------------------------------
; CarpismaKutusu: (AABB Hitbox Math)
; Iki aracin X ve Y eksenindeki mutlak uzakligini hesaplar.
; Mesafe belirli bir esigin altindaysa AL=1 dondurur.
; ----------------------------------------------------------
CarpismaKutusu proc
    mov al, 0           
    mov cl, dh
    sub cl, bh
    jns YKontrol
    neg cl              ; Mutlak deger al
YKontrol:
    cmp cl, 4           ; Y ekseni toleransi
    jg VurmaYok
    mov cl, dl
    sub cl, bl
    jns XKontrol
    neg cl              ; Mutlak deger al
XKontrol:
    cmp cl, 6           ; X ekseni toleransi
    jg VurmaYok
    mov al, 1           ; Tolerans icindeyse carpmistir
VurmaYok:
    ret
CarpismaKutusu endp

; ----------------------------------------------------------
; RastgeleXAl: Sistem saatini okuyarak 3 ihtimalli bir sayi uretir.
; Arabalarin rastgele bir seritte (sol, orta, sag) dogmasini saglar.
; ----------------------------------------------------------
RastgeleXAl proc
    mov ah, 00h
    int 1Ah             
    add dl, rastgele_tohum
    add rastgele_tohum, 13
    mov ax, dx
    xor dx, dx
    mov cx, 3
    div cx              ; CX=3'e bol, kalan (DX) 0,1,2 olur
    mov bx, offset serit_x
    add bx, dx          
    mov al, [bx]        
    ret
RastgeleXAl endp

; ----------------------------------------------------------
; OzelGecikme: Oyunu belirli bir ms dondurarak FPS ayari yapar.
; ----------------------------------------------------------
OzelGecikme proc
    mov cx, oyun_hizi
GecikmeDongusu1:
    push cx
    mov cx, 090         
GecikmeDongusu2:
    nop
    loop GecikmeDongusu2
    pop cx
    loop GecikmeDongusu1
    ret
OzelGecikme endp

; ----------------------------------------------------------
; SkorYazDOS: Final skorunu DOS kesmesi ile konsola basar.
; ----------------------------------------------------------
SkorYazDOS proc
    mov ax, skor
    mov bx, 10
    mov cx, 0
DOSBasamaklaraAyir:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne DOSBasamaklaraAyir
DOSYazdir:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop DOSYazdir
    ret
SkorYazDOS endp

end ana