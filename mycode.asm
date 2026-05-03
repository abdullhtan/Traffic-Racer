                                   ; ==========================================================
; 8086 ASSEMBLY - TRAFFIC RACER (SATIR SATIR ACIKLAMALI)
; ==========================================================

.model small           ; Programýn bellek modunu "small" (kod ve veri için 64KB) ayarla.
.stack 100h            ; 256 byte'lýk bir yýðýn (stack) alaný ayýr.

.data                  ; --- VERI BOLUMU: Degiskenleri burada tanimliyoruz ---
    oyun_hizi      dw 800    ; Islemciyi bekletme suresi (Sayi azaldikca oyun hizlanir).
    min_hiz        dw 400    ; Oyunun ulasabilecegi maksimum hiz siniri.
    hiz_sayaci     db 0      ; Belirli araliklarla hizi artirmak icin kullanilan sayac.
    skor           dw 0      ; Oyuncunun o anki puani.
    en_yuksek_skor dw 0      ; Bilgisayar acik kaldigi surece tutulan rekor puan.
    skor_gecikme   db 0      ; Skorun her dongude degil, 4 dongude 1 artmasi icin fren.
    serit_x        db 28, 40, 52  ; Arabalarin konumlanacagi Sol, Orta, Sag serit koordinatlari.
    oyuncu_x       db 40     ; Sari arabanin baslangic X (yatay) konumu.
    oyuncu_y       db 19     ; Sari arabanin baslangic Y (dikey) konumu.
    engel1_x       db 28     ; 1. rakip arabanin X konumu.
    engel1_y       db 0      ; 1. rakip arabanin Y konumu.
    engel2_x       db 52     ; 2. rakip arabanin X konumu.
    engel2_y       db -12    ; 2. rakip ekranin disindan (gecikmeli) baslasin.
    rastgele_tohum db 0      ; Rastgele serit secmek icin kullanýlan degisken.
    msg_basla      db 'Baslamak icin bir tusa basiniz...$' ; Acilis mesaji.
    msg_temizle    db '                                $' ; Mesaji silmek icin bosluk.
    msg_bitti      db 'OYUN BITTI! Skorunuz: $____'            ; Oyun sonu mesaji.
    msg_rekor      db 'En Yuksek Skor: $'                  ; Rekor mesaji.
    msg_tekrar     db 13, 10, 'SPACE: Tekrar, Q: Cikis$'   ; Secenekler.

.code                  ; --- KOD BOLUMU: Komutlar burada baslar ---

; --- YARDIMCI ROBOTLAR (PROSEDURLER) ---

; Puaný rakam rakam ekrana basan fonksiyon
SkorYaz_Konsol proc
    push ax            ; AX kaydini yedekle.
    push bx            ; BX kaydini yedekle.
    push cx            ; CX kaydini yedekle.
    push dx            ; DX kaydini yedekle.
    mov bx, 10         ; Bolen olarak 10 sayisini kullan (Onluk sistem).
    mov cx, 0          ; Basamak sayisini sifirla.
BasamakAyir_Dongu:
    xor dx, dx         ; Bolme oncesi DX'i sifirla (Hata onleyici).
    div bx             ; Sayiyi 10'a bol (Kalan DX'te durur).
    push dx            ; Bulunan basamagi (kalani) yigina at.
    inc cx             ; Basamak sayisini bir artir.
    cmp ax, 0          ; Bolum 0 oldu mu?
    jne BasamakAyir_Dongu ; Hayirsa bolmeye devam et.
KonsolaBas_Dongu:
    pop dx             ; En son atilan rakami geri al (Ters sira).
    add dl, '0'        ; Sayiyi ASCII karakterine cevir (Örn: 5 -> '5').
    mov ah, 02h        ; DOS ekrana karakter basma fonksiyonu.
    int 21h            ; Ekrana yazdir.
    loop KonsolaBas_Dongu ; Tum basamaklar bitene kadar don.
    pop dx             ; Kayitlari eski haline getir.
    pop cx
    pop bx
    pop ax
    ret                ; Fonksiyondan cik.
SkorYaz_Konsol endp

; Yolun dikey cizgilerini VRAM (Dogrudan Ekran Hafizasi) ile cizen fonksiyon
YolCiz_VRAM proc
    push ax
    push es            ; Ekran segmentini (0B800h) tutacak olan ES'yi yedekle.
    push di            ; Hedef adres DI'yi yedekle.
    push cx
    mov ax, 0B800h     ; Renkli metin modu ekran adresi.
    mov es, ax         ; ES'yi ekrana kilitle.
    mov di, 0          ; Ekranin en basindan basla.
    mov cx, 25         ; 25 satir boyunca ciz.
SatirCiz_Dongu:
    mov ax, 0F7Ch      ; Beyaz renk (0F) ve '|' karakteri (7C).
    mov es:[di + 44], ax   ; 1. serit cizgisini ciz.
    mov es:[di + 68], ax   ; 2. serit cizgisini ciz.
    mov es:[di + 92], ax   ; 3. serit cizgisini ciz.
    mov es:[di + 116], ax  ; 4. serit cizgisini ciz.
    add di, 160        ; Bir alt satira gec (80 karakter * 2 byte = 160).
    loop SatirCiz_Dongu
    pop cx
    pop di
    pop es
    pop ax
    ret
YolCiz_VRAM endp

; Arabayi parcalardan ( [ - ^ ] ) olusturup ekrana cizen fonksiyon
ArabaCiz_VRAM proc
    push ax
    push cx
    push dx
    push di
    push es
    cmp dh, 0          ; Araba ekranin ust sýnýrýnýn dýsýnda mý?
    jl CizimDisi       ; Evetse cizmeyi atla.
    cmp dh, 20         ; Araba ekranýn alt sýnýrýnýn dýsýnda mý?
    jg CizimDisi       ; Evetse cizmeyi atla.
    mov ax, 0B800h     ; VRAM adresi.
    mov es, ax
    mov al, 80         ; Her satirda 80 karakter var.
    mul dh             ; Y koordinati * 80.
    mov ch, 0
    mov cl, dl         ; X koordinatini al.
    add ax, cx         ; Adresi topla.
    shl ax, 1          ; 2 ile carp (Karakter + Renk byte'lari).
    mov di, ax         ; DI artik arabanin sol ust kosesini gosteriyor.
    sub di, 6          ; Gorsel olarak arabanin merkezine kaydir.
    mov ah, bl         ; Parametreyle gelen rengi (Sari/Kirmizi) AH'ye al.
    mov al, '['        ; Araba tamponunu yaz.
    mov es:[di], ax
    mov al, '-'        ; On kaportayi yaz.
    mov es:[di+2], ax
    mov es:[di+4], ax
    mov al, '^'        ; On camý yaz.
    mov es:[di+6], ax
    mov al, '-'        ; Diger kaportayi yaz.
    mov es:[di+8], ax
    mov es:[di+10], ax
    mov al, ']'        ; Diger tamponu yaz.
    mov es:[di+12], ax
    mov al, '|'        ; Tekerlek cizgileri (alt satir).
    mov es:[di+160], ax
    mov es:[di+172], ax
    mov al, '['        ; Arka tampon (2 satir asagi).
    mov es:[di+640], ax
    mov al, '='        ; Arka govde.
    mov es:[di+642], ax
    mov es:[di+644], ax
    mov es:[di+646], ax
    mov es:[di+648], ax
    mov es:[di+650], ax
    mov al, ']'        ; Arka sag tampon.
    mov es:[di+652], ax
CizimDisi:
    pop es
    pop di
    pop dx
    pop cx
    pop ax
    ret
ArabaCiz_VRAM endp

; Arabanin hareket ederken arkasinda biraktigi hayalet goruntuyu siyahla silen fonksiyon
ArabaSil_VRAM proc
    push ax
    push cx
    push dx
    push di
    push es
    cmp dh, 0
    jl SilmeDisi
    cmp dh, 20
    jg SilmeDisi
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
    mov cx, 5          ; Arabanin kapladigi 5 satirlik alaný sil.
    mov ax, 0720h      ; Siyah renk (07) ve Bosluk karakteri (20).
SatirSil_Dongu:
    mov es:[di], ax    ; Yan yana 7 karakteri boslukla doldur.
    mov es:[di+2], ax
    mov es:[di+4], ax
    mov es:[di+6], ax
    mov es:[di+8], ax
    mov es:[di+10], ax
    mov es:[di+12], ax
    add di, 160        ; Bir alt satira gec.
    loop SatirSil_Dongu
SilmeDisi:
    pop es
    pop di
    pop dx
    pop cx
    pop ax
    ret
ArabaSil_VRAM endp

; --- ANA PROGRAMIN BASLANGICI ---
ana proc
    mov ax, @data      ; Veri bolumunu AX'e al.
    mov ds, ax         ; Veri bolumunu DS'ye kilitle.

SifirdanBaslat:        ; Yeniden oyna denilince buraya donulur.
    mov ax, 0003h      ; Ekrani tertemiz standart yazi moduna al.
    int 10h
    mov ah, 01h        ; Yanip sonen imleci gizleme komutu.
    mov cx, 2607h      ; Imleci tamamen yok et.
    int 10h

    ; Degiskenleri ilk haline getir (Yeniden baslama durumunda sifirlanmali).
    mov oyun_hizi, 800
    mov skor, 0
    mov oyuncu_x, 40
    mov engel1_y, 0
    mov engel2_y, -12

    call YolCiz_VRAM   ; Yolu ciz.
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, 0Eh        ; Sari renk.
    call ArabaCiz_VRAM ; Arabayi çiz.
    
    mov ah, 02h        ; Imleci konumlandirma.
    mov dx, 0C14h      ; Ekranin ortasi.
    int 10h
    mov ah, 09h        ; Ekrana yazi basma.
    lea dx, msg_basla  ; Mesaji yukle.
    int 21h            ; "Baslamak icin tusa bas" yazdir.

    mov ah, 00h        ; Klavyeden bir tusa basana kadar bekle.
    int 16h

    mov ah, 02h        ; Ayni yere git.
    mov dx, 0C14h 
    int 10h
    mov ah, 09h
    lea dx, msg_temizle ; Uzerine bosluk yazarak mesaji sil.
    int 21h

Oyunun_Ana_Dongusu:    ; Oyunun kalbi, her sey burada doner.
    ; 1. ADIM: Eski yerdeki arabalari siyahla sil (Goruntu temizligi).
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    call ArabaSil_VRAM
    mov dl, engel1_x
    mov dh, engel1_y
    call ArabaSil_VRAM
    mov dl, engel2_x
    mov dh, engel2_y
    call ArabaSil_VRAM

    ; 2. ADIM: Klavye portunu oku (Akici hareket sistemi).
    in al, 60h         ; Klavyenin 60h nolu donanim portundan sinyali al.
    cmp al, 1Eh        ; Sinyal 'A' tusuna mi ait?
    je SolaKaydir      ; Evetse sola git.
    cmp al, 20h        ; Sinyal 'D' tusuna mi ait?
    je SagaKaydir      ; Evetse saga git.
    jmp HareketBitti   ; Basilmiyorsa devam et.
SolaKaydir:
    cmp oyuncu_x, 26   ; Yolun en soluna mi geldik?
    jle HareketBitti   ; Evetse daha gitme.
    sub oyuncu_x, 2    ; Sari arabayi sola kaydir.
    jmp HareketBitti
SagaKaydir:
    cmp oyuncu_x, 54   ; Yolun en sagina mi geldik?
    jge HareketBitti   ; Evetse daha gitme.
    add oyuncu_x, 2    ; Sari arabayi saga kaydir.
HareketBitti:

    ; 3. ADIM: Rakip (Kirmizi) arabalari asagi kaydir.
    inc engel1_y       ; 1. engeli 1 birim asagi indir.
    cmp engel1_y, 21   ; Ekranin altina ulasti mi?
    jl Engel2_Kontrol  ; Ulasmadiysa 2. engele gec.
    mov engel1_y, 0    ; Ulastýysa tekrar en uste al.
    call RastgeleKonum_Uret ; Yeni dogacagi seridi rastgele sec.
    mov engel1_x, al   ; Yeni serit koordinatini ata.
Engel2_Kontrol:
    inc engel2_y       ; 2. engeli 1 birim asagi indir.
    cmp engel2_y, 21
    jl Engeller_Guncellendi
    mov engel2_y, 0
    call RastgeleKonum_Uret
    mov engel2_x, al
Engeller_Guncellendi:

    ; 4. ADIM: Her seyi yeni koordinatlarinda tekrar ciz.
    call YolCiz_VRAM
    call HizGoster_VRAM
    call SkorGoster_VRAM
    
    mov dl, engel1_x
    mov dh, engel1_y
    mov bl, 0Ch        ; Kirmizi renk.
    call ArabaCiz_VRAM
    mov dl, engel2_x
    mov dh, engel2_y
    mov bl, 0Ch 
    call ArabaCiz_VRAM
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, 0Eh        ; Sari renk.
    call ArabaCiz_VRAM

    ; 5. ADIM: Carpisma var mi kontrol et (Hitbox testi).
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, engel1_x
    mov bh, engel1_y
    call Carpisma_Hesapla ; Carpistik mi?
    cmp al, 1          ; AL=1 ise carpisma var demektir.
    je Carpisma_Var    ; Varsa OyunBitti ekranina git.
    mov dl, oyuncu_x
    mov dh, oyuncu_y
    mov bl, engel2_x
    mov bh, engel2_y
    call Carpisma_Hesapla
    cmp al, 1
    je Carpisma_Var

    call Bekleme_Suresi ; Oyunu insan hizina yavaslatmak icin bekle.
    
    ; 6. ADIM: Skoru guncelle ve oyunu zorlastir.
    inc skor_gecikme   ; Donguyu say.
    cmp skor_gecikme, 4 ; 4 dongude bir...
    jl Hiz_Guncelle
    mov skor_gecikme, 0 ; Sayaci sifirla.
    inc skor           ; ...skoru 1 artir.
Hiz_Guncelle:
    inc hiz_sayaci     ; Her dongu hizlandirma sayacini artir.
    cmp hiz_sayaci, 20 ; 20 dongu gectiyse...
    jl Dongu_Basina_Git
    mov hiz_sayaci, 0  ; Sayaci sifirla.
    mov ax, oyun_hizi  ; Mevcut hizi al.
    cmp ax, min_hiz    ; Maksimum hiza ulasildi mi?
    jle Dongu_Basina_Git
    sub oyun_hizi, 10  ; Bekleme suresini azalt (Yani oyun hizlanir).
Dongu_Basina_Git:
    jmp Oyunun_Ana_Dongusu ; Baþa dön, her seyi tekrarla.

Carpisma_Var:          ; Yandigimizda buraya gelir.
    mov ax, skor       ; Mevcut skoru al.
    cmp ax, en_yuksek_skor ; Rekor mu?
    jle Rekor_Ayni     ; Degilse rekoru guncelleme.
    mov en_yuksek_skor, ax ; Rekoru yeni skor yap.
Rekor_Ayni:
    mov ax, 0003h      ; Ekrani temizle.
    int 10h
    
    mov ah, 02h        ; Imleci konumlandir.
    mov dx, 0819h 
    int 10h
    mov ah, 09h        ; Mesaji yazdir.
    lea dx, msg_bitti
    int 21h
    mov ax, skor       ; Skoru goster.
    call SkorYaz_Konsol
    
    mov ah, 02h        ; Bir alt satira git.
    mov dx, 0A19h 
    int 10h
    mov ah, 09h
    lea dx, msg_rekor  ; Rekoru yazdir.
    int 21h
    mov ax, en_yuksek_skor
    call SkorYaz_Konsol
    
    mov ah, 09h
    lea dx, msg_tekrar ; Secenekleri goster.
    int 21h
Tus_Bekle_Dongu:       ; Oyun bitti ekraninda bir secim bekliyoruz.
    mov ah, 00h
    int 16h
    cmp al, ' '        ; Space tusu mu?
    je Yeniden_Baslat  ; Evetse oyunu sifirla.
    cmp al, 'q'        ; Q tusu mu?
    je Programi_Kapat  ; Evetse cikis yap.
    cmp al, 'Q'
    je Programi_Kapat
    jmp Tus_Bekle_Dongu ; Baþka bir tuþa basýlýrsa beklemeye devam et.
Yeniden_Baslat: jmp SifirdanBaslat
Programi_Kapat: mov ax, 4c00h ; Programi sonlandir ve DOS'a don.
       int 21h
ana endp

; --- MATEMATIKSEL VE DONANIMSAL FONKSIYONLAR ---

; Ýki araba arasýndaki mesafeye bakarak çarpýþma tespit eden robot
Carpisma_Hesapla proc
    mov al, 0          ; Baslangicta carpma yok say (AL=0).
    mov cl, dh         ; Oyuncunun Y koordinati.
    sub cl, bh         ; Rakipten cýkar.
    jns Y_Mesafe       ; Pozitifse mutlak degeri aldýk say.
    neg cl             ; Negatifse pozitif yap (Mutlak deger).
Y_Mesafe: cmp cl, 4    ; Dikey mesafe 4 birimden kucukse carpma olabilir.
    jg Carpma_Yok
    mov cl, dl         ; Oyuncunun X koordinati.
    sub cl, bl         ; Rakipten cýkar.
    jns X_Mesafe
    neg cl
X_Mesafe: cmp cl, 6    ; Yatay mesafe 6 birimden kucukse kesin carpmistir.
    jg Carpma_Yok
    mov al, 1          ; Carpisma tespit edildi (AL=1).
Carpma_Yok: ret
Carpisma_Hesapla endp

; Zamanlayýcýyý kullanarak 0, 1 veya 2 (3 þerit) sayýlarýndan birini üreten robot
RastgeleKonum_Uret proc
    mov ah, 00h
    int 1Ah            ; BIOS'tan sistem saniyesini/tick'ini oku.
    add dl, rastgele_tohum ; Tohum ekle (Daha iyi rastgelelik icin).
    add rastgele_tohum, 13 ; Tohumu bir sonraki sefer icin degistir.
    mov ax, dx         ; Zaman degerini AX'e al.
    xor dx, dx         ; DX'i temizle.
    mov cx, 3          ; 3'e bol.
    div cx             ; Kalan (DX) 0, 1 veya 2 olur.
    mov bx, offset serit_x ; Serit listesinin basini bul.
    add bx, dx         ; Kalan kadar listede ilerle.
    mov al, [bx]       ; O seridin koordinatini listeden al.
    ret
RastgeleKonum_Uret endp

; Islemciyi bos donguye sokarak zaman kazanan (gecikme yapan) robot
Bekleme_Suresi proc
    mov cx, oyun_hizi  ; Gecikme miktarini yukle.
Dis_Bekle: push cx     ; CX'i sakla.
     mov cx, 90        ; Ic dongu degeri.
Ic_Bekle: nop          ; Hicbir sey yapma (Zaman gecir).
     loop Ic_Bekle     ; Ic donguyu bitir.
     pop cx            ; CX'i geri al.
     loop Dis_Bekle    ; Dis donguyu bitir.
    ret
Bekleme_Suresi endp

; Ekranýn sag ustune "HIZ: 120" gibi veriyi yazan robot
HizGoster_VRAM proc
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    mov ax, 0B800h
    mov es, ax
    mov di, 130         ; Ekrandaki yeri (Sütun: 65, Satir: 0).
    mov ah, 0Fh         ; Beyaz renk.
    mov al, 'H'         ; Metni yaz.
    mov es:[di], ax
    mov al, 'I'
    mov es:[di+2], ax
    mov al, 'Z'
    mov es:[di+4], ax
    mov al, ':'
    mov es:[di+6], ax
    ; Hizi matematiksel hesapla.
    mov ax, 800
    sub ax, oyun_hizi   ; Bekleme suresi azaldikca sonuc artar.
    shr ax, 3           ; Sayiyi normallestir.
    add ax, 50          ; Minimum hizi ekle.
    mov bl, 10
    div bl              ; Sayiyi basamaklarina ayir.
    mov dl, ah
    xor ah, ah
    div bl
    mov ch, al          ; Yuzler basamagi.
    mov cl, ah          ; Onlar basamagi.
Hiz_Sifir_Kontrol:
    mov al, ch
    add al, '0'
    cmp al, '0'         ; Yuzler basamagi 0 ise...
    jne Hiz_Yazdir
    mov al, ' '         ; ...bosluk goster (080 yerine 80).
Hiz_Yazdir:
    mov ah, 0Fh
    mov es:[di+10], ax
    mov al, cl
    add al, '0'
    mov es:[di+12], ax
    mov al, dl
    add al, '0'
    mov es:[di+14], ax
    pop es              ; Kayitlari kurtar.
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
HizGoster_VRAM endp

; Ekranin sag tarafina "SKOR: 0005" yazan robot
SkorGoster_VRAM proc
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    mov ax, 0B800h
    mov es, ax
    mov di, 290         ; 2. satira git.
    mov ah, 0Fh         ; Beyaz.
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
    mov ax, skor        ; Mevcut skoru al.
    mov bx, 10
    mov cx, 4           ; 4 basamak olsun.
Basamaklari_Yigina_At: 
    xor dx, dx
    div bx              ; 10'a bolerek basamaklara ayir.
    push dx             ; Basamaklari yigina at.
    loop Basamaklari_Yigina_At
    mov cx, 4
    add di, 10
Yigindan_Ekrana_Bas: 
    pop dx              ; Basamaklari geri cikar (Dogru sirayla gelir).
    add dl, '0'         ; Karakter yap. Rakam artik DL'de.
    mov al, dl          ; <--- COZUM: DL'deki karakteri AL'ye kopyala.
    mov ah, 0Fh         ; Renk kodu AH'ye yazildi.
    mov es:[di], ax     ; AX (Yani AH=Renk ve AL=Karakter) ekrana basilir.
    add di, 2           ; Yana gec.
     loop Yigindan_Ekrana_Bas
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SkorGoster_VRAM endp

end ana ; Programin sonu.