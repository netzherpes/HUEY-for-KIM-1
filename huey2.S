;   huey.h65,  ReSource65: v 0.91a,  Mar  7 2008
;
;   HUEY!  by Don Rindsberg
;             The Bit Stop
;             P.O. Box 973
;             Mobile, AL 36601
;
;   Original article published in Kilobaud magazine with code
;   provided as a hex dump (similar to *.H65 format).
;
;   Source code reconstructed and typos in published
;   listing corrected by C. Bond.
;
;   Two errors in the hex listing and their corrected values
;   are as follows:
;
;        PUBLISHED               CORRECTED
;      Location Value          Location Value
;      -------- -----          -------- -----
;       1156     A2             1156     A6
;       1474     57             1474     56
;
;
;   HUEY! was evidently written for an early version
;   of the 6502 processor (pre June, 1976) because there
;   is no use of ROR instructions. Instead, ROR is
;   implemented with equivalent code or subroutines.
;
;   BINARY NUMBER FORMAT
;
;   Number storage in Huey is in the following 7-byte format:
;
;       Byte: 0 1 2 3 4 5 6
;             | | | | | | |
;             | `-`-`-`-`-`--------- 6-byte signed mantissa
;             `--------------------- 1-byte exponent
;
;   The exponent, byte 0, ranges from -128 to 127. It is encoded
;   by adding 128 to the actual exponent. The highest bit is then
;   comparable to a sign bit, where a 1 signifies a positive
;   exponent and a 0 signifies a negative exponent. The exponent
;   range supports equivalent decimal numbers ranging from about
;   10^(-37) to 10^(37).
;
;   The highest bit in byte 1 is the mantissa sign bit. In this
;   case a 1 signifies a negative mantissa and a 0 signifies a
;   positive mantissa.
;
        .print xref,stats
        .files h65

xreg        .equ $0020  ; 'x' $20-$26   RPN stack working registers
ereg        .equ $0027
expon       .equ $002E
integ       .equ $002F
yreg        .equ $0030  ; 'y' $30-$36     "
memm1       .equ $0037
tempin      .equ $003E
tempout     .equ $003F
zreg        .equ $0040  ; 'z' $40-$46     "
memm2       .equ $0047
strptr      .equ $004E
strptrh     .equ $004F
treg        .equ $0050  ; 't' $50-$56     "
memm3       .equ $0057
ctr0        .equ $005E  ; g.p. counter
ctr1        .equ $005F  ; g.p. counter
ureg        .equ $0060  ; 'u' $60-$66   RPN stack buffer register
vreg        .equ $0067  ; 'v' $67-$6D     "
tptr        .equ $006E
tptrh       .equ $006F
dreg        .equ $0070  ; 'd' $70-$7F   Decimal register
breg        .equ $0080  ; 'b' $80-$8F   Line buffer/decimal workspace
xjsr        .equ $0090  ; on-the-fly subroutine call
nxtad       .equ $0091  ;    $20 xx yy $60, where xx = nxtad
nxtadh      .equ $0092  ;    and yy = nxtadh
xrts        .equ $0093  ; return code
sgn         .equ $0094
radr        .equ $0095  ; tmp storage for strptr ptr
radrh       .equ $0096
ctr2        .equ $0097  ; g.p. counter
expn2       .equ $0098
sqflg       .equ $0099
tbrk        .equ $009A
crt3        .equ $009B  ; g.p. counter
lstkey      .equ $009D  ; last key pressed 
lbuff       .equ $009E  ; buffer pointer
lbuffh      .equ $009F
zpend       .equ $00A0 
;
;  misc constants and 'magic' numbers
;
jsr_op      .equ $20    ; opcode for jsr
rts_op      .equ $60    ; opcode for rts
cr          .equ $0d
lf          .equ $0a
get         .equ $80    ; high bit flag for get to 'xreg'
put         .equ $1     ; low bit flag for put from 'xreg'
kofst       .equ '*'+10 ; offset key lookup list by smallest token value
eos         .equ 0      ; End Of String 'mu_str' terminator
;
;   misc token definitions
;
enter       .equ get+<m_xx
xchg        .equ <m_xy
;
;   The following lines are used to specify the addresses of
;   external input and output routines. They are set to zero
;   here so the listing will match the published code.
;
;   In a KIM-1 system, 'inchar' is $1F6A and outchar is $1F1F.
;
inchar      .equ 0
outchar     .equ 0

            .org $2000 
cldstrt     jmp initrun
wrmstrt     jmp run    
charin      jmp inchar 
charout     jmp outchar

defchar     .byte '\'          ; default character
expsym      .byte '*'          ; symbol identifying exponent
numdig      .byte $09          ; number of digits ($2-$D)
bkspc       .byte $08          ; backspace
            .byte $18          ; expansion
delay       .byte $01          ; minimum delay
tabchr      .byte $1B          ; tab
null        .byte $00  

initrun     ldy #(zpend-xreg)  ; clear F.P. workspace
            ldx #xreg          
            jsr clr_spc        
run         ldx #$FF           ; initialize stack
            txs                
            cld                
            lda #jsr_op        ; create indirect jsr
            sta xjsr           
            lda #rts_op        
            sta xrts           
            jsr crlf            
            jsr clr_d          
            jsr prt_num        
mainlp      ldy >(breg+1)      ; initialize line buffer ptr
            sty lbuffh         
            lda <(breg+1)      ; buffer: $81-$8f 
            sta lbuff          
            nop                
            nop                
            nop                
            nop                
            nop                
prompt      lda #':'           
put_ch      jsr charout        ; print prompt and get
get_ch      jsr charin         ;  next key
            ldy #$00           ; set character index
            cld                
            and #$7F           ; scrape off any high bit
            cmp bkspc          
            beq backsp         ; back up 1 char
            cmp tabchr         
            bne @F             
            jmp tabexp         ; tab to exponent
@           cmp #'*'           ; ignore characters below '*'
            bcc get_ch         ;  or above 'Z'
            cmp #'Z'+1         
            bcs get_ch         ; try again
            cmp #'0'           
            bcc fix_op         ; filter out operators
            cmp #':'           
            bcs sav_key        ; filter out digits
            sbc #'0'-1         ; make number zero based
            sta lstkey         ; (carry was clear)
            lda lbuff          ; check buffer ptr
            cmp #(breg+1)      ; 1st char?
            bne @F              
            jsr clr_d          ; clear 'dreg' if new entry
@           lda lbuff          ; check number of chars
            sec                     
            sbc numdig          
            cmp #(breg+3)      ; too many chars?
            beq rst_buff       ; yes, reset buffer
            cmp #breg          
            beq strt_exp       ; move into exponent
            lda lbuff           
            cmp #(breg+1)      ; 1st char?
            sec                ; use carry as flag
            bne @F             
            clc                
@           jsr key2buff       ; put key in buffer
            bcs get_ch          
            lda #'.'           ; if 1st char...
            bcc put_ch         ; ...print decimal point
strt_exp    jsr prt_xsym       
            sec                
            bcs @B             ; branch always

backsp      dec lbuff          
rst_buff    ldx defchar        
            jmp clrchar         
fix_op      clc                ; add 10 to operators
            adc #10            ; *  +  ,  -  .  /
sav_key     sta lstkey         
            jsr mov_b2d        
            jsr crlf           
            ldy <mu_str        ; set ptr to mu_op strings
            sty strptr         
            lda >mu_str        
            sta strptrh        
            jsr ex_str         ; execute default entry string 
            ldx lstkey         
            lda k2adr-kofst,x  
            tax                
            jsr do_str         ; find and execute mu_op string
            lda <defexit       
            sta strptr         
            lda >defexit       
            sta strptrh        
            jsr ex_str         ; execute default exit string
            jmp mainlp         
;
;   string address descriptor is in accumulator
;   find address and execute string
;
do_str      and #%00000011     ; get page ID (0-3)
            clc                
            adc >mu_str        ; base page for op strings
            sta strptrh        ; set mu_op string page
            txa                
            and #%11111100     ; get offset in page
            sta strptr         ; set muop string address...
            jmp ex_str         ; ...and execute it

;
;   bump mu_op string pointer to next mu_op
;
nxt_muop    inc strptr         
            bne @F             
            inc strptrh        
@           rts                

            brk                
            brk                

tabexp      lda #(breg+1)      ; tab to exponent position
            clc                
            adc numdig         
            cmp lbuff          ; check current position
            bne @F               
            jsr prt_xsym       ; if there, print exp symbol
            jmp get_ch         ;  and get next character
@           lda #'0'           ; fill with zeros to
            jsr charout        ;  exponent position
            inc lbuff          
            bne tabexp         ; branch always

            nop                

ex_str      ldy #$00           
            lda (strptr),y     
            beq endxstr        
            jsr ex_mu          ; execute mu_op
            sec                ; increment mu string ptr
            inc strptr         
            bne @F             
            inc strptrh        
@           bcs ex_str         ; execute mu_ops to 
endxstr     rts                ;  end of string (null)

ex_mu       php                ; 'a' has descriptor
            pha                
            and #%01111110     ; scrape off get/save bits
            tax                   
            lda adrtbl,x       ; put mu_op address in
            sta nxtad          ; staging pointer
            lda adrtbl+1,x     
            sta nxtadh         
            pla                
            plp                
            bmi mem2x          ; hi bit set? m -> x
            lsr                
            bcs x2mem          ; lo bit set? x -> m
            jmp xjsr           ; execute mu_op
mem2x       jmp recallm        ; get number to 'xreg'
x2mem       jmp movx2m         ; save 'xreg' to memory
;
;   zero 'xreg' if number is too small
;
uflow       lda xreg              
            cmp #$60           
            bcs @F             
            lda <k0            ; get 0.0000...
            sta nxtad          
            lda >k0            
            sta nxtadh         
            jsr recallm        ; ...and copy to 'xreg'
@           rts                
;
;   clear 'd' if 'x' = 0
;
test_x      lda xreg           
            beq @F             
            jmp x_notzr        
@           ldy #$10           
            ldx #dreg          
            jmp clr_spc        ; clear 'dreg'
;
;   clear 'x if 'd' = 0
;
test_d      lda dreg+2         
            bne @F             
            ldx dreg+3         ; *** 1156 A6 73 was: 1156 A2 73
            bne @F             
            ldx #xreg          
            ldy #$07           
            jmp clr_spc        ; clear 'x'
@           jmp d_notzr        
            pla                
            pla                
            sta tbrk           
            pla                
            jsr byt2asc        
            lda tbrk           
            jsr byt2asc        
            jmp run            
;
;   convert byte in accumulator to two ASCII hex characters
;   and print
;
byt2asc     pha                ; save it
            lsr                ; isolate hi nibble
            lsr                
            lsr                
            lsr                
            jsr hex2asc        ; print it
            jsr charout         
            pla                
            and #$0F           ; isolate lo nibble...
            jsr hex2asc        ; ...and print it
            jsr charout         
            rts                
;
;   convert low nibble in accumulator to ASCII
;
hex2asc     cmp #$0A           ; 0..9?
            bcs @F             ; no, must be A..F
            adc #$30           ; yes, make ASCII numeral
            rts                
@           adc #$36           ; make alphabetic
            rts                

clrchar     tya                ; offset into 'lbuff'
            sta (lbuff),y      
            txa                
            nop                
            nop                
            jmp put_ch         

            .fill 16,0
;
;   miscellaneous constants I
;
;  0.5000000000
;
khlf        .byte $7F,$40,$00,$00 
            .byte $00,$00,$00
;
;   4.000000000
;
kp4         .byte $82,$40,$00,$00 
            .byte $00,$00,$00
;
;   0,69314718056
;
kln2        .byte $7F,$58,$B9,$0B 
            .byte $FB,$E8,$E6
;
;   0.434294481903
;
klge        .byte $7E,$6F,$2D,$EC 
            .byte $54,$9B,$92
;
;   1.41421356237
;
ksq2        .byte $80,$5A,$82,$79 
            .byte $99,$FC,$E4
;
;   polynomial coefficients for approximations
;
;
;   C00 = 1.29200685024
;
c00         .byte $80,$52,$B0,$3D 
            .byte $80,$00,$00
;
;   C01 = -2.63985773921
;
c01         .byte $81,$AB,$86,$49 
            .byte $10,$00,$00
;
;   C02 = 1.65676237643
;
c02         .byte $80,$6A,$08,$65 
            .byte $10,$00,$00
;
;   C03 = 87.4174956704
;
c03         .byte $86,$57,$6A,$E0 
            .byte $FF,$0A,$80
;
;   C04 = 617.972290039
;
c04         .byte $89,$4D,$3F,$1D 
            .byte $00,$00,$00
;
;   C05 = 0.0346573591232  ln(2)/20
;
c05         .byte $7B,$46,$FA,$70 
            .byte $00,$00,$00
;
;   C06 = 9.95459613949
;
c06         .byte $83,$4F,$A3,$03 
            .byte $4D,$00,$00

            .org $2200

adrtbl      .word $0000        ; $00
m_add       .word add_         ; $02 Add
m_sub       .word sub_         ; $04 Subtract
m_mul       .word mul_         ; $06 Multiply
m_div       .word div_         ; $08 Divide
m_sqi       .word sqinit       ; $0A Sqrt setup
m_sqx       .word sqx          ; $0C Square root cleanup
m_prn       .word prt_num      ; $0E Display number in 'dreg'
m_xy        .word swapxy       ; $10 Swap 'xreg' and 'yreg'
m_stk       .word stk_adj      ; $12 Drop stack
m_lgi       .word log_init     ; $14 Convert to base 2 format
m_chx       .word chk_xx       ; $16 Handle exponent range
m_xaj       .word xadj         ; $18 Adjust 'xreg' exponent
m_d2x       .word d2x          ; $1A Convert 'dreg' to 'xreg'
m_x2d       .word x2d          ; $1C Convert 'xreg' to 'dreg'
m_int       .word int_         ; $1E Integer part of 'xreg'
m_xnrm      .word xnorm        ; $20 Reformat 
m_ilp       .word init_ctr     ; $22 Initialize loop ctr2
m_sav       .word sav_sptr     ; $24 Save string pointer
m_rpt       .word rpt_lp       ; $26 Repeat loop
m_swp       .word swapm3x      ; $28 swap 'memm3' with 'xreg'
m_roll      .word roll_up      ; $2A Roll stack up
m_cr        .word crlf         ; $2C Print cr/lf
m_clrd      .word clr_d        ; $2E Clear 'dreg'
m_ufl       .word uflow        ; $30 Get 0.000 to 'xreg'
m_call      .word call_str     ; $32 Call string as subroutine
m_sc2       .word set_ctr2     ; $34 Initialize ctr2 
            .word $0000        ;        unused
            .word $0000        ;           "
            .word $0000        ;           "
            .word $0000        ;           "
            .word $0000        ;           "
            .word $0000        ; $40       "
            .word $0000        ;           "
            .word $0000        ;           "
            .word $0000        ;           "
m_p1p       .word kp1p         ; $48/$C8   
m_hlf       .word khlf         ; $4A/$CA
m_p4        .word kp4          ; $4C/$CC
m_mm1       .word memm1        ; $4F/$CE put/get memm1 - x
m_mm2       .word memm2        ; $51/$D0 put/get memm2 - x  
m_mm3       .word memm3        ; $53/$D2 put/get memm3 - x
m_xx        .word xreg         ; $D4 dup 'x'
m_zr        .word k0           ; $D6 get  0.0000... to 'xreg'
m_p1        .word kp1          ; $D8 get  1.0000... to 'xreg'
m_m1        .word km1          ; $DA get -1.0000... to 'xreg'
m_p2        .word kp2          ; $DC get  2.0000... to 'xreg'
m_p3        .word kp3          ; $DE get  3.0000... to 'xreg'
m_rts       .word rtrn         ; $60  NOP 
m_p5        .word kp5          ; $E2 get  5.00000... to 'xreg'
m_m7        .word km7          ; $E4 get -7.0000... to 'xreg'
m_p10       .word kp10         ; $E6 get 10.0000... to 'xreg'
m_e         .word ke           ; $E8 get  2.71828... to 'xreg'
m_pi        .word kpi          ; $EA get  3.14159... to 'xreg'
m_ln2       .word kln2         ; $EC get  0.69314... to 'xreg'
m_lge       .word klge         ; $EE get  0.43429... to 'xreg'
m_sq2       .word ksq2         ; $F0 get  1.41421... to 'xreg' 
;
;  addresses of polynomial coefficients for ln(x) routine
;
m_c00       .word c00 
m_c01       .word c01          
m_c02       .word c02          
m_c03       .word c03          
m_c04       .word c04          
m_c05       .word c05          
m_c06       .word c06          
;
; move stack down after xreg op yreg -> xreg; does not affect xreg
;
stk_adj     ldx #$06           
@           lda zreg,x         
            sta yreg,x         
            lda treg,x         
            sta zreg,x         
            lda ureg,x         
            sta treg,x         
            lda vreg,x         
            sta ureg,x         
            dex                
            bpl @B             
rtrn        rts                
;
;   roll stack up:  x -> y -> z -> t -> x
;                                    
roll_up     ldx #$06           
@           lda xreg,x         
            ldy yreg,x         
            sta yreg,x         
            lda zreg,x         
            sty zreg,x         
            ldy treg,x         
            sta treg,x         
            sty xreg,x         
            dex                
            bpl @B             
            ldy #$00           
            rts                
;
;   get memory reg to 'x' and move stack up
;
recallm     ldx #$06           
            ldy #$06           
@           lda ureg,x         
            sta vreg,x         
            lda treg,x         
            sta ureg,x         
            lda zreg,x         
            sta treg,x         
            lda yreg,x         
            sta zreg,x         
            lda xreg,x         
            sta yreg,x         
            lda (nxtad),y      
            sta xreg,x         
            dey                
            dex                
            bpl @B             
            iny                
            rts                
;
;   move 'x' to memory register
;
movx2m      ldx #xreg+6        
            ldy #$06           
@           lda $00,x          
            sta (nxtad),y      
            dex                
            dey                
            bpl @B              
            iny                
            rts                
;
;   exchange memory register 3 with 'x'
;
swapm3x     ldx #$06           
@           lda memm3,x        
            ldy xreg,x         
            sta xreg,x         
            sty memm3,x        
            dex                
            bpl @B             
            rts                
            .fill 6,0
;
;   0.0000000000
;
k0          .byte $00,$00,$00,$00 
            .byte $00,$00,$00
;
;   1.0000000000
;
kp1         .byte $80,$40,$00,$00 
            .byte $00,$00,$00

;
;   convert binary contents of 'xreg' to decimal format in 'dreg'
;
x2d         jmp test_x         
x_notzr     nop                
            nop                
            nop                
            ldy #$00           
            sty dreg           
            lda xreg+1         
            bpl @F             
            dec dreg           
            jsr neg_x          
@           ldy #$00           
            sty dreg+1         
divby10     lda xreg           ; count multiples of 10
            cmp #$7F           
            beq x2d0           
            bcc @F             
            jsr swapxy         
            jsr get10          ; put '10' in 'xreg'
            jsr divx           
            lda dreg+1         
            jsr inc_d          
            sta dreg+1         
            clv                
            bvc divby10        ; branch always

@           cmp #$7A           
            bcc @F             
            jsr shfxrt         ; shift extended right
            clv                
            bvc divby10        ; branch always

@           jsr swapxy         
            jsr get10          
            jsr mul_           
            lda dreg+1         
            jsr dec_d          
            sta dreg+1         
            clv                
            bvc divby10        ; branch always

x2d0        ldx #dreg+2        
            jsr clr_14         ; clear 'dreg'
            ldx #breg+2        
            jsr clr_14         ; clear 'breg'
            lda #$05           
            sta breg+2         
            ldx #xreg+6        
            ldy #$06           
            jsr dblreg         ; double 'x' reg 
            lda #$30           
            sta ctr1           
@           ldx #xreg+6        
            ldy #$06           
            jsr dblreg         ; double 'x' reg
            dec ctr1           
            beq @F1            
            bcc @F             
            ldx #dreg+15       
            ldy #breg+15       
            jsr addb2d         
@           ldx #breg+2        
            jsr shfbrt         
            clv                
            bvc @B1            ; branch always

@           lda dreg+1         
            jsr dec_d          
            sta dreg+1         
            nop                 
            nop                
            nop                
            nop                
            nop                
            nop                 
            rts                

clr_14      ldy #14            ; clear 14 byte space
clr_spc     lda #$00           ; clear 'y' bytes starting 
@           sta $00,x          ;  at z.p. location 'x'
            inx                
            dey                
            bne @B             
            rts                
;
;   shift a binary register left one bit
;
dblreg      asl $00,x          
            dex                
            dey                
@           rol $00,x          
            dex                
            dey                
            bne @B             
            rts                
;
;   increment decimal number in accumulator
;
inc_d       clc                
            sed                
            adc #$01           
            cld                
            rts                
;
;   decrement decimal number in accumulator
;
dec_d       sec                
            sed                
            sbc #$01           
            cld                
            rts                
;
;   put '10' in 'xreg'
;
get10       ldx #xreg          
            ldy #$07           
            jsr clr_spc        
            lda #$83           
            sta xreg           
            lda #$50            
            sta xreg+1         
            rts                

addb2d      lda #$0E           
            sta tptrh          
            sed                
            clc                
@           lda $0000,y         
            adc $00,x          
            pha                
            and #$0F           
            sta $00,x          
            pla                
            and #$10           
            beq @F             
            sec                
@           dex                
            dey                
            dec tptrh          
            bne @B1            
            cld                
            rts                

shfbrt      cld                
            lda #$0D           
            sta tptrh          
@           lsr $00,x          
            bcc @F             
            inx                
            lda #$09           
            adc $00,x          
            sta $00,x          
            dex                
@           inx                
            dec tptrh          
            bne @B1             
            nop                
            nop                
            rts                
        .align 256,0
;
;   convert number in 'dreg' to binary in 'xreg
;
d2x         jmp test_d         
d_notzr     nop                
            nop                
            nop                
            lda dreg+1         
            jsr inc_d          
            sta dreg+1         
            ldx #xreg          
            ldy #$07           
            jsr clr_spc        ; clear 'xreg'
            lda #$80           
            sta xreg           
            lsr                
            sta xreg+1         
@           lda dreg+1         
            tay                
            beq @F1            
            clc                
            sed                
            adc #$50           
            cmp #$50           
            cld                
            bcc @F              
            tya                
            jsr dec_d          
            jsr iget10         
            jsr mul_            
            clv                
            bvc @B             ; branch always
@           tya                
            jsr inc_d           
            jsr iget10         
            jsr divx           
            clv                
            bvc @B1            ; branch always
@           jsr swapxy         
            ldx #xreg          
            ldy #$07           
            jsr clr_spc        ; clear 'xreg'
            ldx #vreg          
            ldy #$07           
            jsr clr_spc        ; clear 'vreg' 
            lda #$40           
            sta vreg+1         
            lda #$2F           
            sta ctr0           
d2x2        jsr dbl_d          ; double 'dreg'
            bcc shfvrt         
            ldx #$06           
@           lda vreg,x          
            ora xreg,x         
            sta xreg,x         
            dex                
            bne @B             
shfvrt      clc                
            ldx #-6            
@           lda #$80           
            bcs @F             
            asl                ; shift 'vreg' right
@           lsr tptr,x         ; *** 1474 56 6E was: 57 6E
            ora tptr,x         
            sta tptr,x         
            inx                
            bne @B1            
            dec ctr0           
            bne d2x2           
            lda #$7F           
            sta xreg           
            lda dreg            
            bmi @F1            
            jsr int_lp         
@           jsr mul_            
            nop                
            nop                
            nop                
            rts                
@           jsr neg_x           
            clv                
            bvc @B1            
iget10      sta dreg+1         
            jsr swapxy         
            jsr get10          
            rts                

dbl_d       ldx #(dreg+15)     
            ldy #$0E           
            sed                
            clc                
dbl_lp      lda $00,x          
            adc $00,x          
            pha                
            and #$0F           
            sta $00,x          
            pla                
            and #$10           
            clc                
            beq @F             
            sec                
@           dex                
            dey                
            bne dbl_lp         
            cld                
            rts                
            .byte $00,$00          
;
;   miscellaneous constants II
;
;   -1.000000000
;
km1         .byte $7F,$80,$00,$00 
            .byte $00,$00,$00
;
;   2.0000000000
;
kp2         .byte $81,$40,$00,$00 
            .byte $00,$00,$00
;
;   3.0000000000
;
kp3         .byte $81,$60,$00,$00 
            .byte $00,$00,$00

;
;   handle overflow and underflow of 'xreg'
;
chk_xx      lda xreg+2         
            sta integ          
            sec                
            sbc #$7C           
            lda xreg+1         
            sbc #$00           
            bpl xov_err        
            clc                
            lda xreg+2         
            adc #$78           
            lda xreg+1         
            adc #$00           
            bpl nclr_x         

clr_xr      lda #$00           
            ldx #$06           
@           sta xreg,x         
            dex                
            bpl @B             
nclr_x      rts                

xov_err     brk                ; exponent overflow error

xadj        sec                
            lda integ          
            adc xreg           
            sta xreg           
            rts                
;
;   the following table translates an input key to an
;   address in the micro-instruction string list
;
;   addresses are at 4-byte boundaries starting at page
;   labelled 'mu_str'. the format of the address
;   descriptor is:
;
;           bit 7 6 5 4 3 2 1 0
;               x x x x x x y y
;
;   where the x's are the addresses within a page, and the y's
;   are the page offsets starting with page mu_str. Note that the
;   micro-operation strings MUST start on a 4-byte boundary and
;   the the first string MUST begin on a page boundary where the
;   page is a multiple of 4 ($18,$1C,$20,....). The published
;   location is page $18.
;
;   To encode the micro-instruction string address from 2 bytes
;   to 1 byte, first take the difference between the page of the
;   string and the start of the micro-instruction string table.
;   Add this number (0-3) to the low byte of the string address.
;   Thus a string at $19E0 would encode to $E1 ($E0+$19-$18).
;
k2adr       .byte <s_mul+>s_mul->mu_str ; *   Multiply
            .byte <s_sum+>s_sum->mu_str ; +   Add
            .byte <s_nop+>s_nop->mu_str ; ,   (not used)
            .byte <s_sub+>s_sub->mu_str ; -   Subtract
            .byte <s_nop+>s_nop->mu_str ; .   (not used)
            .byte <s_div+>s_div->mu_str ; /   Divide
            .byte <s_nop+>s_nop->mu_str ; :   (not used)
            .byte <s_nop+>s_nop->mu_str ; ;   (not used)
            .byte <s_m1x+>s_m1x->mu_str ; <   M1 -> x  
            .byte <s_nop+>s_nop->mu_str ; =   (not used)
            .byte <s_xm1+>s_xm1->mu_str ; >   x -> M1
            .byte <s_atn+>s_atn->mu_str ; ?   Arctan
            .byte <s_clr+>s_clr->mu_str ; @   Clear entry
            .byte <s_alg+>s_alg->mu_str ; A   Antilog x (base 10)
            .byte <s_nop+>s_nop->mu_str ; B   (not used)
            .byte <s_cos+>s_cos->mu_str ; C   Cos x (radians)
            .byte <s_nop+>s_nop->mu_str ; D   (not used)
            .byte <s_exp+>s_exp->mu_str ; E   e^x
            .byte <s_nop+>s_nop->mu_str ; F   (not used)
            .byte <s_log+>s_log->mu_str ; G   Log x (base 10)
            .byte <s_nop+>s_nop->mu_str ; H   (not used)
            .byte <s_i+>s_i->mu_str     ; I   1/x
            .byte <s_nop+>s_nop->mu_str ; J   (not used)
            .byte <s_stk+>s_stk->mu_str ; K   Display stack
            .byte <s_ln+>s_ln->mu_str   ; L   ln x
            .byte <s_nop+>s_nop->mu_str ; M   (not used)
            .byte <s_neg+>s_neg->mu_str ; N   Enter as negative
            .byte <s_nop+>s_nop->mu_str ; O   (not used)
            .byte <s_pos+>s_pos->mu_str ; P   Enter as positive
            .byte <s_sqr+>s_sqr->mu_str ; Q   Square root of x
            .byte <s_rol+>s_rol->mu_str ; R   Roll stack up
            .byte <s_sin+>s_sin->mu_str ; S   Sin x
            .byte <s_tan+>s_tan->mu_str ; T   Tan x
            .byte <s_pi+>s_pi->mu_str   ; U   Recall Pi to x
            .byte <s_e+>s_e->mu_str     ; V   Recall e to x
            .byte <s_lge+>s_lge->mu_str ; W   Recall log e (base 10) to x
            .byte <s_xy+>s_xy->mu_str   ; X   Exchange x and y
            .byte <s_nop+>s_nop->mu_str ; Y   (not used)
            .byte <s_nop+>s_nop->mu_str ; Z   (not used)
            .byte <s_nop+>s_nop->mu_str ; (filtered out)
            .byte <s_nop+>s_nop->mu_str 
            .byte <s_nop+>s_nop->mu_str 
;
;   miscellaneous constants III
;
;
;   1.0000000000+
;
kp1p        .byte $80,$40,$00,$00 
            .byte $00,$00,$20
;
;   5.0000000000
;
kp5         .byte $82,$50,$00,$00 
            .byte $00,$00,$00
;
;   -7.0000000000
;
km7         .byte $82,$90,$00,$00 
            .byte $00,$00,$00
;
;   10.000000000
;
kp10        .byte $83,$50,$00,$00 
            .byte $00,$00,$00
;
;   2.71828182846
;
ke          .byte $81,$56,$FC,$2A 
            .byte $2C,$51,$5E
;
;   3.14159265359
;
kpi         .byte $81,$64,$87,$ED 
            .byte $51,$10,$B2
            .byte $00          

init_ctr    lda #$09           
            nop                 
            sta ctr2           
            rts                

sav_sptr    lda strptr         ; save mu_str ptr
            sta radr           
            lda strptrh        
            sta radrh          
            rts                

            .fill 6,0

rpt_lp      dec ctr2           
            beq @F             
            lda radr           ; restore mu_str ptr
            sta strptr         
            lda radrh          
            sta strptrh         
@           rts                

sqinit      lda xreg+1         ; check sign of mantissa
            bpl @F             

sqdmerr     brk                ; square root domain error

@           lda xreg           ; normalize exponent for
            sta expn2          ;  square root of mantissa
            lda #$80           
            sta xreg           
            rts                

sqx         lda #$00           
            sta sqflg          
            lsr expn2          
            bcc @F             
            inc sqflg          
@           asl expn2          
            lda expn2          
            bpl @F             
            sec                
            sbc #$80            
            lsr                
            clc                
            adc #$80           
            bcc sqx1           
@           lda #$80           
            sec                
            sbc expn2          
            lsr                
            clc                
            adc expn2          
sqx1        sta xreg           
            lda sqflg          
            beq @F             
            lda <ksq2          
            sta nxtad          
            lda >ksq2          
            sta nxtadh         
            jsr recallm        
            jsr mul_           
            jsr stk_adj        
@           rts                
;
;   convert number in 'xreg' to M * 2^E  format
;
log_init    lda xreg+1         ; check sign
            beq lderr          
            bpl @F             

lderr       brk                ; log domain error

@           jsr swapxy         
            ldx #$80           
            lsr tempin         
            lda yreg           
            bmi @F             
            stx tempin         
            sec                
            lda #$00           
            sbc yreg           
@           stx yreg           
            sec                
            sbc #$80           
            sta xreg+2         
            lda #$00           
            sta xreg+1         
            jsr int_           
            asl tempin         
            bcc lgx            
            ldx #$05           
@           lda #$00           
            sbc xreg+1,x       
            sta xreg+1,x       
            dex                
            bpl @B             
lgx         rts                

clr_frac    jsr clr_spc        
            lda #$8E           
            sta xreg           
            jmp int_lp         

;
;   add 'yreg' mantissa to 'xreg'
;
addy2x      clc                
            ldx #$05           
@           lda xreg+1,x       
            adc yreg+1,x       
            sta xreg+1,x       
            dex                
            bpl @B             
            rts                

twopass     asl sgn            
            jsr onepass        
onepass     bit xreg+1         ; check sign of mantissa
            bpl @F             
            jsr neg_x          
            inc sgn            
@           sec                
swapxy      ldx #$07           ; swap 'xreg' and 'yreg'
@           sty ereg-1,x       ; (save 'yreg' to 'ereg')
            lda xreg-1,x       
            ldy yreg-1,x       
            sty xreg-1,x       
            sta yreg-1,x       
            dex                
            bne @B             
            rts                

int_        ldx #xreg+3        
            ldy #$07           
            jmp clr_frac       

ilp0        dec xreg           
            asl xreg+6         
            ldx #$05           
@           rol xreg,x         
            dex                
            bne @B             
int_lp      lda xreg+1         ; test for 01... or 10...
            asl                
            eor xreg+1          
            bmi @F             
            lda xreg           
            bne ilp0           
@           rts                
;
;   subtract
;
sub_        jsr neg_x          
@           jsr add0           
;
;   add
;
add_        lda yreg           
            cmp xreg           
            bne @B             
            jsr addy2x         
add1        bvc int_lp         
            bvs @F             ; branch always

add0        bcc swapxy         ; reorder x,y
shfxrt      lda xreg+1         
            asl                
@           inc xreg           
            beq ov_brk         
shfert      ldx #-12           ; shift extended register 
@           lda #$80           ; provisional previous bit
            bcs @F             
            asl                ; clear provisional bit
@           lsr ereg+6,x       
            ora ereg+6,x       ; 'a' will have rotated bit
            sta ereg+6,x       
            inx                 
            bne @B1            
            rts                

mul_        jsr twopass        
            adc xreg           
            jsr div2           
            clc                
@           jsr shfert         
            bcc @F             
            jsr addy2x         
@           dey                
            bpl @B1            
chksgn      lsr sgn            
mul1        bcc int_lp         
neg_x       sec                
            ldx #$06            
@           lda #$00           
            sbc xreg,x         
            sta xreg,x         
            dex                
            bne @B             
            beq add1           ; branch always

divx        jsr twopass        
            sbc xreg           
            jsr div2           
div1        sec                
            ldx #$05           
@           lda yreg+1,x        
            sbc ereg,x         
            pha                
            dex                
            bpl @B             
            ldx #-6            
@           pla                
            bcc @F             
            sta memm1,x        
@           inx                
            bne @B1            
            ldx #6             
@           rol xreg,x         
            dex                
            bne @B             
            asl yreg+6         
            ldx #5             
            jsr yt2x           ; multiply 'yreg' by 2
            dey                
            bne div1           
            beq chksgn         
div2        php                
            jsr fillx          
            plp                
            nop                
            bcs chk_ov          
            bmi @F             
            pla                
            pla                
            bcc mul1           
@           eor #$80           
            sta xreg           
            ldy #$2F           
            rts                

chk_ov      bpl @B             
ov_brk      brk                
@           jsr shfxrt          
xnorm       lda xreg           
            cmp #$8E           
            bne @B             
            rts                

fillx       ldy #$06           ; fill 'xreg' with value in x
@           stx xreg,y         
            dey                
            bne @B             
            rts                

            nop                
yt2x        rol yreg,x         ; yreg * 2
            dex                
            bne yt2x           
            bcs ov_brk         
            rts                

;
;   transfer last key to line buffer
;
key2buff    lda lstkey         
            sta (lbuff),y      
            inc lbuff          
            rts                
;
;   print cr/lf to output
;
crlf        lda #cr            
            jsr charout         
            lda #lf            
            jsr charout        ; 'y' affects delay
;
;   delay for slow I/O devices
;
;   'x' = 'y' = 0 gives longest delay
;   'x' = 'y' = 1 gives shortest delay
;
            ldx delay          
@           dey                
            bne @B             
            dex                
            bne @B             
            rts                

            nop                
            nop                
            nop                
            nop                

mov_b2d2    ldx #(breg+1)      ; move decimal mantissa
            ldy #(dreg+2)      ; from 'breg' to 'dreg'
            lda numdig          
            sta crt3           
@           lda $00,x          
            sta $0000,y         
            inx                
            iny                
            dec crt3           
            bne @B             
            rts                

mov_b2d     jsr mov_b2d2       ; move mantissa
            ldx numdig         ; pack exponent 
            lda breg+1,x       
            asl                
            asl                
            asl                
            asl                
            ora breg+2,x       
            sta dreg+1         
            lda breg           
            sta dreg           
            lda breg+1,x       ; check sign of exponent
            bpl @F             
            sed                ; if negative exponent...
            sec                ; ...subtract from 0
            lda #$00           
            sbc dreg+1         
            sta dreg+1         
@           cld                ; back to binary mode
            rts                

clr_d       ldx #dreg          ; clear decimal regs
            ldy #$20           
            jsr clr_spc         
            rts                

            nop
            nop                

out_digit   ora #'0'           ; convert digit to ASCII
            jsr charout        
            rts                

div_        lda xreg           
            beq div_zr         
            jmp divx           

div_zr      brk                ; divide by zero error
            .fill 5,0
;
;   print number in 'dreg' to terminal
;
prt_num     lda #' '           ; output correct sign
            ldx dreg           
            bpl @F             
            lda #'-'           ; negative mantissa
@           jsr charout         
            lda dreg+2         
            jsr out_digit      ; print 1st digit...
            lda #'.'           ; ...and decimal point
            jsr charout        
            ldx numdig         
            dex                
            stx tempin         
            ldx #$00           
            stx tempout        
@           ldx tempout        ; do rest of mantissa digits
            lda dreg+3,x       
            jsr out_digit       
            inc tempout        
            dec tempin         
            bne @B             
            lda expsym         ; now output exponent symbol
            jsr charout        
            lda dreg+1         
            cmp #$50           
            bcc @F             
            lda #'-'           ; and sign
            jsr charout        
            sec                
            sed                ; negate exponent if
            lda #$00           ; sign is negative
            sbc dreg+1         
            cld                
            clv                
            bvc prt_exp        ; branch always
@           lda #' '           
            jsr charout         
            lda dreg+1         
prt_exp     pha                ; print exponent
            lsr                
            lsr                
            lsr                
            lsr                
            jsr out_digit      ; 1st exponent digit
            pla                
            and #$0F           
            jsr out_digit      ; 2nd exponent digit
            jmp crlf           ; finish off with cr/lf

prt_xsym    lda expsym         
            jsr charout        
            lda #' '           
            jsr charout        
            rts                

call_str    jsr nxt_muop       
            ldy #$00           
            lda (strptr),y     
            tax                
            lda strptr         ; save current ptr
            pha                
            lda strptrh        
            pha                
            txa                
            jsr do_str         ; execute mu_str
            pla                ; and restore ptr
            sta strptrh        
            pla                
            sta strptr          
            rts                

            brk                
            brk                
            brk                
set_ctr2    lda #$03           
            sta ctr2           
            rts
            .align 256,0
;
;   microinstruction string lists
;
;   the first string is the (unused) default entry string
;
            .org $2800
mu_str      .fill 8,0
;
;   default exit processing
;
defexit     .byte m_mm3+put    ; Save 'xreg' in 'memm3'
            .byte get+m_p1p    ; Get 'kp1p' (1.00+) to 'xreg'
            .byte m_mul        ; Multiply (quick-and-dirty round)
            .byte m_x2d        ; Convert 'xreg' to 'dreg'
            .byte m_prn        ; Show number in 'dreg'
            .byte m_stk        ; Move stack down
            .byte m_swp        ; Exchange 'memm3' with 'xreg'
            .byte eos

            .align 4,0
            .fill 4,0
;
;   'P' key -- enter a number with zeros automatically filled in
;
s_pos       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_d2x        ; Convert 'dreg' to 'xreg'
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
;
;   '*' key -- multiply; 'xreg' * 'yreg' -> 'xreg'
;
s_mul       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_stk        ; Move stack down
            .byte m_stk        ; Move stack down
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
;
;   'W' key -- recall log (base 10) of e
;
s_lge       .byte get+m_lge    
            .byte eos

            .align 4,0
;
;   '/' key -- divide; 'yreg' / 'xreg' -> 'xreg'
;
s_div       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_stk        ; Move stack down
            .byte m_stk        ; Move stack down
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
            .fill 4,0
;
;   '@' key -- clear entry
;
s_clr       .byte m_cr         ; print cr/lf
            .byte m_clrd       ; clear 'dreg'
            .byte eos

            .align 4,0
;
;   xreg -> memm1
;
s_xm1       .byte put+m_mm1    ; Put 'xreg' in 'memm1' 
            .byte eos

            .align 4,0
;
;   memm1 -> xreg
;
s_m1x       .byte get+m_mm1    ; Get 'memm1' to 'xreg'
            .byte eos

            .align 4,0
;
;   'U' key -- recall Pi to 'xreg'
;
s_pi        .byte get+m_pi     ; Get 'kpi' (3.14..) to 'xreg'
            .byte eos

            .align 4,0
;
;   'V' key -- recall E (exp(1)) to 'xreg'
;
s_e         .byte get+m_e      ; Get 'ke' (2.718..) to 'xreg'
            .byte eos

            .align 4,0
;
;   'I' key -- make reciprocal of 'xreg'
;
s_i         .byte get+m_p1     ; Get 'kp1' (1.00..) to 'xreg'
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
;
;   'N' key -- enter as negative
;
s_neg       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_d2x        ; Convert 'dreg' to 'xreg'
            .byte m_stk        ; Move stack down
            .byte get+m_m1     ; Get 'km1' (-1.00..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte eos          
;
;   'X' key -- swap 'xreg' and 'yreg'
;
s_xy        .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte eos

            .align 4,0
            .fill 4,0

s_nop       .fill 4,0          ; Just put minimum (4-bytes) '0' fill
;
;   '+' key -- add; 'xreg' + 'yreg' -> 'xreg'
;
s_sum       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_stk        ; Move stack down
            .byte m_stk        ; Move stack down
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
            .fill 4,0
;
;   '-' key -- subract; 'yreg' - 'xreg' -> 'xreg'
;
s_sub       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_stk        ; Move stack down
            .byte m_stk        ; Move stack down
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte m_ufl        ; Handle underflow
            .byte eos

            .align 4,0
            .fill 4,0
;
;   'R' key -- roll stack up
;
s_rol       .byte m_roll       ; Roll stack up 
            .byte eos

            .align 4,0
;
;   'L' key -- ln(x)
;
s_ln        .byte enter        ; Enter
            .byte m_lgi        ; Convert to M*2^E format
            .byte put+m_mm2    ; Save 'xreg' in 'memm2' 
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte put+m_mm3    ; Save 'xreg' in 'memm3'
            .byte m_stk        ; Move stack down 
            .byte get+m_sq2    ; Get 'ksq2' (1.4142..) to 'xreg;
            .byte m_sub        ; Subtract 
            .byte m_stk        ; Move stack down
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte get+m_sq2    ; Get 'ksq2' (1.4142..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte enter        ; Enter
            .byte put+m_mm3    ; Save 'xreg' in 'memm3'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_c02    ; Get 'C02' to 'xreg'
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte get+m_c01    ; Get 'C01' to 'xreg'
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_c00    ; Get 'C00' to 'xreg'
            .byte m_add        ; Add  
            .byte m_stk        ; Move stack down
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down 
            .byte get+m_hlf    ; Get 'khlf' (0.500..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_ln2    ; Get 'kln2' (0.693..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
            .fill 4,0
;
;   'E' key -- exp(x)
;
s_exp       .byte get+m_ln2    ; Get 'kln2' (0.693..) to 'xreg'
            .byte m_div        ; Divide 
            .byte m_stk        ; Move stack down
            .byte enter        ; Enter 
            .byte m_xnrm       ; Reformat 'xreg'
            .byte m_chx        ; Adjust exponent
            .byte m_int        ; Take integer part of 'xreg'
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte put+m_mm2    ; Save 'xreg' to 'memm2'
            .byte enter        ; Enter
            .byte m_mul        ; Multiply 
            .byte m_stk        ; Move stack down 
            .byte put+m_mm3    ; Save 'xreg' to 'memm3'
            .byte get+m_c03    ; Get C03
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_c04    ; Get C04
            .byte xchg         ; Swap 'xreg' and 'yreg
            .byte m_div        ; Divide 
            .byte m_stk        ; Move stack down
            .byte get+m_c05    ; Get C05
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte get+m_c06    ; Get C06
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte xchg         ; Swap 'xreg' and 'yreg' 
            .byte m_div        ; Divide
            .byte get+m_hlf    ; Get 'khlf' (0.50..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte m_xaj        ; Adjust exponent
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
            .fill 4,0
;
;   'Q' key -- take square root of argument in 'xreg'
;
s_sqr       .byte m_sqi        ; check square root domain
            .byte put+m_mm3    ; Save 'xreg' in 'memm3'
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_stk        ; Drop stack
            .byte get+m_p2     ; Get 'kp2' (2.00..) to 'xreg'
            .byte m_ilp        ; Initialize loop counter
            .byte m_sav        ; Save mu_ptr
            .byte put+m_mm2    ; Save 'xreg' in 'memm2'
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_stk        ; Drop stack
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Drop stack
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Drop stack
            .byte get+m_p2     ; Get 'kp2' (2.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Drop stack
            .byte m_rpt        ; Loop until done
            .byte m_sqx        ; Take square root 
            .byte eos

            .align 4,0
            .fill 8,0
;
;   'S' key -- Sin(x)
;
s_sin       .byte put+m_mm3    ; Save 'xreg' in 'memm3'
            .byte enter        ; Enter
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p10    ; Get 'kp10' (10.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_p10    ; Get 'kp10' (10.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_p10    ; Get 'kp10' (10.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_hlf    ; Get 'khlf' (0.500..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_p1     ; Get 'kp1' (3.14..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_p1     ; Get 'kp1' (3.14..) to 'xreg'
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_p10    ; Get 'kp10'(10.00..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_m7     ; Get 'km7' (-7.00..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p3     ; Get 'kp3' (3.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte get+m_p5     ; Get 'kp5' (5.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte put+m_mm3    ; Save 'xreg' to 'memm3'
            .byte enter        ; Enter
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte put+m_mm2    ; Save 'xreg' to 'memm2'
            .byte get+m_p4     ; Get 'kp4' (4.000..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p4     ; Get 'kp4' (4.000..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p4     ; Get 'kp4' (4.000..) to 'xreg'
            .byte get+m_p5     ; Get 'kp5' (5.000..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte m_rts        ; NOP
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p5     ; Get 'kp5' (5.00..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0    
;
;   'K' key -- display stack
;
s_stk       .byte m_sc2        ; Initialize counter 2
            .byte m_roll       ; Roll stack up
            .byte m_sav        ; Save mu_ptr
            .byte put+m_mm3    ; Save 'xreg' in 'memm3'
            .byte get+m_p1p    ; Get 'kp1p' (1.00+..) to 'xreg'
            .byte m_mul        ; ..and round 'xreg'
            .byte m_x2d        ; Convert to decimal..
            .byte m_prn        ; ..and print it
            .byte m_stk        ; Move stack down
            .byte m_swp        ; Swap 'xreg' and 'memm3'
            .byte m_roll       ; Roll stack up
            .byte m_rpt        ; Repeat for x,y,z,t regs.
            .byte eos

            .align 4,0
;
;   'C' key -- cos(x)
;
s_cos       .byte get+m_pi     ; Get 'kpi' (3.14..) to 'xreg'
            .byte get+m_p2     ; Get 'kp2' (2.00..) to 'xreg'
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte xchg         ; Swap 'xreg' and 'yreg' 
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte m_call       ; Set up to...
            .byte <s_sin+>s_sin->mu_str  ; ...execute sin(x)
            .byte eos

            .align 4,0
            .fill 4,0
;
;   'G' key -- log x (base 10)
;
s_log       .byte m_call       ; Set up to...
            .byte  <s_ln+>s_ln->mu_str   ; ...execute ln(x)
            .byte get+m_lge    ; Get log E (base 10) (0.434..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
;
;   'A' key -- antilog x (base 10)
;
s_alg       .byte get+m_lge    
            .byte m_div        
            .byte m_stk        ; Move stack down
            .byte m_call       ; Set up to ...
            .byte <s_exp+>s_exp->mu_str ; ...execute exp(x)
            .byte eos

            .align 4,0
;
;   'T' key -- tangent function
;
s_tan       .byte m_call       ; Set up to...
            .byte <s_sin+>s_sin->mu_str ; ...execute sin(x)
            .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p1     ; Get 'kp1' (1.00..) to 'xreg' 
            .byte xchg         ; Swap 'xreg' and 'yreg'
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte m_call       ; Set up to ...
            .byte <s_sqr+>s_sqr->mu_str  ; ...execute sqrt(x)
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte eos

            .align 4,0
            .fill 44,0
;
;   '?' key -- arctan(x)
;
s_atn       .byte m_call       ; Set up to ...
            .byte <s_xxx+>s_xxx->mu_str ; ... execute function
            .byte m_call       ; Do again.
            .byte <s_xxx+>s_xxx->mu_str 
            .byte enter        ; Enter
            .byte m_mul        ; Multiply
            .byte get+m_m1     ; Get km1 (-1.00..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte put+m_mm3    ; Save 'xreg' to 'memm3'
            .byte get+m_p5     ; Get 'kp5' (5.00..) to 'xreg'
            .byte get+m_p4     ; Get 'kp4' (4.00..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte get+m_p1     ; Get 'kp1' (1.00..) to 'xreg'
            .byte m_sub        ; Subtract
            .byte put+m_mm2    ; Put 'xreg' to 'memm2'
            .byte get+m_p1     ; Get 'kp1' (1.00..) to 'xreg'
            .byte m_ilp        ; Initialize loop counter
            .byte m_sav        ; Save mu_ptr
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte m_mul        ; Multiply
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte m_div        ; Divide
            .byte get+m_mm2    ; Get 'memm2' to 'xreg'
            .byte get+m_p2     ; Get 'kp2' (2.00..) to 'xreg'
            .byte m_sub        ; Subtract
            .byte m_stk        ; Move stack down
            .byte put+m_mm2    ; Put 'xreg' to 'memm2'
            .byte m_mul        ; Multiply
            .byte get+m_p1     ; Get 'kp1' (1.00..) to 'xreg'
            .byte m_add        ; Add
            .byte m_rpt        ; Repeat loop
            .byte get+m_mm3    ; Get 'memm3' to 'xreg'
            .byte get+m_m1     ; Get 'km1' (-1.00..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte m_call       ; Set up to ...
            .byte <s_sqr+>s_sqr->mu_str  ; ... execute sqrt(x)
            .byte m_mul        ; Multiply
            .byte get+m_p4     ; Get kp4 (4.00..) to 'xreg'
            .byte m_mul        ; Multiply
            .byte eos

            .align 4,0
;
; This string is used internally by the 'arctangent' functions
;
s_xxx       .byte enter        ; Enter
            .byte enter        ; Enter
            .byte m_mul        ; Multiply
            .byte m_stk        ; Move stack down
            .byte get+m_p1     ; Get 'kp1' (1.00..)
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte m_call       ; Set up to ...
            .byte <s_sqr+>s_sqr->mu_str ; ... execute sqrt(x)
            .byte get+m_p1     ; Get 'kp1' (1.00..) to 'xreg'
            .byte m_add        ; Add
            .byte m_stk        ; Move stack down
            .byte m_div        ; Divide
            .byte m_stk        ; Move stack down
            .byte eos

            .align $100,0      ; pad with zeros to next page
;
;   end of huey
;

            .end
                                 
