; Tatu Laras 2023
; TODO: 
; controller input ns. flappy bird
; sound
; music


.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:
load_palettes:
  lda $2002
  lda #$3f
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
@loop:
  lda palettes, x
  sta $2007
  inx
  cpx #$20
  bne @loop

; fill nametable 0 with tiles

bit $2002 ; reset latch
lda #$20 ; nametable start address to PPUADDR
sta $2006
lda #$00
sta $2006

lda #$01 ; tile to use

ldx #$f0 ; counter

loop_nt:
  dex

  sta $2007
  sta $2007
  sta $2007
  sta $2007

  bne loop_nt


; attribute table filling not needed, default pallette in use


; vine columns

bit $2002 ; reset latch
lda #%10000100	; increment mode column
sta $2000

bit $2002 ; reset latch
lda #$20 ; nametable start address to PPUADDR
sta $2006
lda #$0b
sta $2006

lda #$02 ; tile to use

ldx #$0f ; counter

loop_vn:
  dex
  sta $2007
  bne loop_vn


bit $2002 ; reset latch
lda #$20 ; nametable start address to PPUADDR
sta $2006
lda #$1e
sta $2006

lda #$02 ; tile to use

ldx #$08 ; counter

loop_vn2:
  dex
  sta $2007
  bne loop_vn2


enable_rendering:
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00011110	; Enable rendering BGRs bMmG
  sta $2001


; windows (as sprites / OAM) starting at $0204

  lda #$6c        ; y-pos
  sta $0204
  lda #$03        ; tile
  sta $0205
  lda #%00000001  ; attributes
  sta $0206 
  lda #$6c         ; x-pos
  sta $0207

  lda #$6c        ; y-pos
  sta $0208
  lda #$03        ; tile
  sta $0209
  lda #%01000001  ; attributes
  sta $020a 
  lda #$74         ; x-pos
  sta $020b

  lda #$74        ; y-pos
  sta $020c
  lda #$03        ; tile
  sta $020d
  lda #%10000001  ; attributes
  sta $020e 
  lda #$6c         ; x-pos
  sta $020f

  lda #$74        ; y-pos
  sta $0210
  lda #$03        ; tile
  sta $0211
  lda #%11000001  ; attributes
  sta $0212 
  lda #$74         ; x-pos
  sta $0213


  lda #$6c        ; y-pos
  sta $0214
  lda #$03        ; tile
  sta $0215
  lda #%00000001  ; attributes
  sta $0216 
  lda #$ac         ; x-pos
  sta $0217

  lda #$6c        ; y-pos
  sta $0218
  lda #$03        ; tile
  sta $0219
  lda #%01000001  ; attributes
  sta $021a 
  lda #$b4         ; x-pos
  sta $021b

  lda #$74        ; y-pos
  sta $021c
  lda #$03        ; tile
  sta $021d
  lda #%10000001  ; attributes
  sta $021e 
  lda #$ac         ; x-pos
  sta $021f

  lda #$74        ; y-pos
  sta $0220
  lda #$03        ; tile
  sta $0221
  lda #%11000001  ; attributes
  sta $0222 
  lda #$b4         ; x-pos
  sta $0223

; windows end ---


; --- memory map ---
;   $0020 character x pos
;   $0021 character y pos
;   $0022 character flags hor. direction +-, vert. direction +-, unused


; character starting attributes

; pos
lda #$6c
sta $20
sta $21

; flags
lda #%00000000
sta $22

forever:
  ; ---  game logic  ---


  ; character position calculation

  ; collisions with walls

  ; if y > max
  lda $21
  cmp #$e0
  bcc :+
  lda #%10000000 ; set vert. flag
  ora $22
  sta $22
  :

  ; if y < min
  lda $21
  cmp #$08
  bcs :+
  lda #%01111111 ; clear vert. flag
  and $22
  sta $22
  :

  ; if x > max
  lda $20
  cmp #$f6
  bcc :+
  lda #%01000000 ; set hor. flag
  ora $22
  sta $22
  :

  ; if x < min
  lda $20
  cmp #$04
  bcs :+
  lda #%10111111 ; clear hor. flag
  and $22
  sta $22
  :


  ; setup OAM page $02XX
  lda $21        ; y-pos
  sta $0200
  lda #$00        ; tile
  sta $0201
  lda $22  
  and #%01000000
  ora #%00000000 ; attributes FFP---pp 
  sta $0202 
  lda $20        ; x-pos
  sta $0203


  jmp forever


nmi:
; backup the registers
  pha
  txa
  pha
  tya
  pha


  ldx #$00 	; OAMADDR to 0 (using OAMDMA instead)
  stx $2003

  ; scroll to 0
  bit $2002 ; reset latch
  stx $2005
  stx $2005

  lda #$02 ; copy page 2 of cpu ram to OAM
  sta $4014


  

  ; increment character position according to flags

  lda #%01000000
  and $22

  beq :+ ; bit 7
  dec $20
  :

  lda #%01000000
  and $22

  bne :+
  inc $20
  :

  lda $22

  bpl :+ ; bit 7
  dec $21
  :

  lda $22

  bmi :+
  inc $21
  :



; restore registers from backup
  pla
  tay
  pla
  tax
  pla

  rti


palettes:
  ; Background Palette
  .byte $0f, $17, $27, $29
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; Sprite Palette
  .byte $0f, $20, $10, $0f
  .byte $0f, $17, $27, $22
  .byte $0f, $2c, $1c, $0f
  .byte $0f, $26, $16, $0f

; Character memory
; 
.segment "CHARS"
  .byte %01111110 ; character
  .byte %11111110
  .byte %11111110
  .byte %11111110
  .byte %11111110
  .byte %11111110
  .byte %11111100
  .byte %00000000

  .byte %00000000
  .byte %00000001
  .byte %00000001
  .byte %00001011
  .byte %00000001
  .byte %00011111
  .byte %00000011
  .byte %01111110


  .byte %11110111 ; brick
  .byte %11110111
  .byte %00000000
  .byte %11011111
  .byte %11011111
  .byte %00000000
  .byte %11110011
  .byte %11110111

  .byte %00001000
  .byte %00001000
  .byte %11111111
  .byte %00100000
  .byte %00100000
  .byte %11111111
  .byte %00001100
  .byte %00001000

  .byte %11110111 ; brick w/vine
  .byte %11110111
  .byte %00000001
  .byte %11011111
  .byte %11011111
  .byte %00000101
  .byte %11110011
  .byte %11110111

  .byte %00001011
  .byte %00001001
  .byte %11111111
  .byte %00100001
  .byte %00100011
  .byte %11111111
  .byte %00001101
  .byte %00001001

  .byte %11111111 ; window
  .byte %10000000
  .byte %10000000
  .byte %11011010
  .byte %11011010
  .byte %11000000
  .byte %11011010
  .byte %11011010

  .byte %00000000
  .byte %01111111
  .byte %00111111
  .byte %00111111
  .byte %00111111
  .byte %00111111
  .byte %00111111
  .byte %00111111