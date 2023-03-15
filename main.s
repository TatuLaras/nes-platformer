; Tatu Laras 2023
; TODO: 

PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
OAMADDR = $2003
PPUSCROLL = $2005
PPUADDR = $2006
PPUDATA = $2007
OAMDMA = $4014

JOYPAD1 = $4016
JOYPAD2 = $4017

.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

; interrupt jump addresses
.segment "VECTORS"
  .addr nmi
  .addr reset
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
  stx PPUCTRL	; disable NMI
  stx PPUMASK 	; disable rendering
  stx $4010 	; disable DMC IRQs

; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit PPUSTATUS
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

main:
load_palettes:
  lda PPUSTATUS
  lda #$3f
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #$00
@loop:
  lda palettes, x
  sta PPUDATA
  inx
  cpx #$20
  bne @loop


; load starting nametable
bit PPUSTATUS ; reset latch
lda #$20 ; nametable start address to PPUADDR
sta PPUADDR
lda #$00
sta PPUADDR


ntPtr = $00 ; nametable pointer
lda #<nametable_contents
sta ntPtr+0
lda #>nametable_contents
sta ntPtr+1

ldx #4 ; do this loop 4 times
ldy #0
:
	lda (ntPtr), y
	sta PPUDATA
	iny
	bne :-
	dex
	beq :+ ; finished if X = 0
	inc ntPtr+1 ; ptr = ptr + 256
	jmp :- ; loop again: Y = 0, X -= 1, ptr += 256
:


; second wait for vblank, PPU is ready after this
vblankwait2:
  bit PPUSTATUS
  bpl vblankwait2


enable_rendering:
  lda #%10010000	; Enable NMI
  sta PPUCTRL
  lda #%00011110	; Enable rendering BGRs bMmG
  sta PPUMASK


; --- memory macros ---
controllerButtons = $20
charXPos = $21
charYPos = $22
charXVelocity = $23
charYVelocity = $24
tempXVelocity = $25
tempYVelocity = $26
xVelocitySign = $27
yVelocitySign = $28

; --- value macros ---
inputAcceleration = $04
passiveDeceleration = $01
maxVelocityValue = $f7

; initial character attributes
lda #$30
sta charXPos
lda #$d0
sta charYPos

lda #%01111111
sta charXVelocity
sta charYVelocity

; game logic
forever:

  ; populate oam copy in ram page 02

  ; player character / bubble metasprite

  lda charYPos
  sta $0200

  lda #$03 ; tile index
  sta $0201
  
  lda #%00000000 ; attributes
  sta $0202

  lda charXPos
  sta $0203


  lda charYPos
  sta $0204

  lda #$04 ; tile index
  sta $0205
  
  lda #%00000000 ; attributes
  sta $0206

  lda charXPos
  adc #$08
  sta $0207

  lda charYPos
  adc #$08
  sta $0208

  lda #$04 ; tile index
  sta $0209
  
  lda #%11000000 ; attributes
  sta $020A

  lda charXPos
  sta $020B

  lda charYPos
  adc #$08
  sta $020C

  lda #$02 ; tile index
  sta $020D
  
  lda #%00000000 ; attributes
  sta $020E

  lda charXPos
  adc #$08
  sta $020F




  jmp forever


nmi:
; backup the registers
  pha
  txa
  pha
  tya
  pha


  ldx #$00 	; OAMADDR to 0 (using OAMDMA instead)
  stx OAMADDR

  ; scroll to 0
  bit PPUSTATUS ; reset latch
  stx PPUSCROLL
  stx PPUSCROLL

  lda #$02 ; copy page 2 of cpu ram to OAM
  sta OAMDMA

  jsr readjoy

  ldx controllerButtons

  txa
  and #%00000001 ; right
  beq :+

  lda charXVelocity ; clamp
  cmp #maxVelocityValue
  bcs :+

  adc #inputAcceleration
  sta charXVelocity
  :

  txa
  and #%00000010 ; left
  beq :+

  lda charXVelocity ; clamp
  cmp #inputAcceleration
  bcc :+

  sbc #inputAcceleration
  sta charXVelocity
  :

  txa
  and #%00000100 ; down
  beq :+
  
    lda charYVelocity ; clamp
    cmp #maxVelocityValue
    bcs :+

    adc #inputAcceleration
    sta charYVelocity
  :

  txa
  and #%00001000 ; up
  beq :+
    lda charYVelocity ; clamp
    cmp #inputAcceleration
    bcc :+

    sbc #inputAcceleration
    sta charYVelocity
  :

  ; friction
 
  lda charXVelocity
  cmp #%01111111
  bcs :+
    adc #passiveDeceleration
    jmp :++
  :
    sbc #passiveDeceleration
  :

  sta charXVelocity

  lda charYVelocity
  cmp #%01111111
  bcs :+
    adc #passiveDeceleration
    jmp :++
  :
    sbc #passiveDeceleration
  :

  sta charYVelocity


  ; velocity => pos

    
  ; x
  
  ; store sign
  lda charXVelocity
  asl a
  lda #$00
  sta xVelocitySign
  rol xVelocitySign
  
  lda charXVelocity
  ; if x > 7f then x - 7f
  bpl :+
    lda charXVelocity
    sbc #%01111111
    sta tempXVelocity
    dec tempXVelocity

    jmp :++
  : ; else 7f - x
    lda #%01111111
    sbc charXVelocity
    sta tempXVelocity
    inc tempXVelocity
  :

  ; temp x >> 5
  ldx #$05
  :
  lsr tempXVelocity
  dex
  bne :-

  ; add to x pos
  lda tempXVelocity
  beq :+
  lda charXPos
  adc tempXVelocity
  sta charXPos
  :


  ; y
  
  ; store sign
  lda charYVelocity
  asl a
  lda #$00
  sta yVelocitySign
  rol yVelocitySign


  lda charYVelocity

  ; if x > 7f then x - 7f
  bpl :+
    lda charYVelocity
    sbc #%01111111
    sta tempYVelocity
    dec tempYVelocity

    jmp :++
  : ; else 7f - x
    lda #%01111111
    sbc charYVelocity
    sta tempYVelocity
    inc tempYVelocity
  :

  ; temp x >> 5
  ldx #$05
  :
  lsr tempYVelocity
  dex
  bne :-

  ; add to y pos
  lda tempYVelocity
  beq @dont_add

    lda yVelocitySign
    ; if plus
    bne :+
      lda charYPos
      sbc tempYVelocity
      jmp :++
    :
      lda charYPos
      dec tempYVelocity
      adc tempYVelocity
    :

  sta charYPos
  @dont_add:


; restore registers from backup
  pla
  tay
  pla
  tax
  pla

  rti



; -----------------------

readjoy:
    lda #$01
    ; While the strobe bit is set, buttons will be continuously reloaded.
    ; This means that reading from JOYPAD1 will only return the state of the
    ; first button: button A.
    sta JOYPAD1
    sta controllerButtons
    lsr a        ; now A is 0
    ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
    ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
    sta JOYPAD1
loop:
    lda JOYPAD1
    lsr a	       ; bit 0 -> Carry
    rol controllerButtons  ; Carry -> bit 0; bit 7 -> Carry
    bcc loop
    rts

palettes:
  ; background Palette
  .byte $0f, $2c, $1c, $3c
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; sprite Palette
  .byte $0f, $31, $21, $20
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

nametable_contents:
  .incbin "sprites.nam"

; load pattern table binaries
.segment "CHARS"
  .incbin "sprites.chr"
 