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
charXPos = $20 ; character X position
charYPos = $21 ; character Y position


; game logic
forever:

  ; populate oam copy in ram page 02
  lda charXPos
  sta $0200

  lda #$00
  sta $0201
  
  lda #%00000000
  sta $0202

  lda charYPos
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
  stx OAMADDR

  ; scroll to 0
  bit PPUSTATUS ; reset latch
  stx PPUSCROLL
  stx PPUSCROLL

  lda #$02 ; copy page 2 of cpu ram to OAM
  sta OAMDMA


  inc charXPos
  inc charYPos


; restore registers from backup
  pla
  tay
  pla
  tax
  pla

  rti


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
 