; ==========================================================================
; DEATH HANDLER, GAME OVER & SCORING ($C617-$C7B4)
; ==========================================================================
;
; CHECK PAUSE ($C617):
;   Checks if P key is pressed. If so, displays pause overlay and waits.
;
; DEATH HANDLER ($C64F):
;   Called when collision detected (bit 0 of $B0C8):
;     1. Flash animation: field alternates normal/inverted colors
;     2. Continue moving chasers during death animation (they keep patrolling)
;     3. Decrement lives ($B0C2)
;     4. If lives > 0: restart level ($C377) - grid preserved, entities reset
;     5. If lives == 0: game over sequence
;   NOTE: No sound effects during level complete, but death handler plays
;   buzzing/explosion sounds via port $FE output.
;
; GAME OVER ($C674):
;   Displays "GAME OVER" overlay with rainbow cycling.
;   Same popup rectangle mechanism as level complete.
;
; OUT OF TIME ($C6C9):
;   Displays "OUT OF TIME" then falls through to game over.
;
; SCORE FINALIZE ($C6F6):
;   Adds (rawPercentage + filledPercentage) * 4 to base score.
;   Clears both percentage accumulators to 0.
;
; PERCENTAGE CALCULATION ($C780):
;   1. Count claimed cells -> rawPercent = count / 90
;      (divisor 90 from LD DE,$005A at $C785)
;   2. Count all non-empty cells -> fillPercent = (count - 396) / 90
;      (396 = border cell count: 124*2 + 74*2)
;   3. If fillPercent >= 75 (CP $4B at $C7A5): set bit 2 of $B0C8
;   Display score = base_score + (rawPercent + fillPercent) * 4
;


; --- Check pause ---
CHECK_PAUSE:	CALL	XBA9D		; c617  cd 9d ba	M.:
	RET	C		; c61a  d8		X
	CALL	RESET_BRIGHT_FIELD		; c61b  cd d3 d3	MSS
	LD	BC,X0B08	; c61e  01 08 0b	...
	LD	DE,X0710	; c621  11 10 07	...
	LD	A,68H		; c624  3e 68		>h
	CALL	DRAW_BORDERED_RECT		; c626  cd 70 bf	Mp?
	LD	HL,XC5EC	; c629  21 ec c5	!lE
	CALL	STRING_RENDERER		; c62c  cd 26 bc	M&<
	LD	HL,XC610	; c62f  21 10 c6	!.F
	CALL	XBF18		; c632  cd 18 bf	M.?
XC635:	CALL	XBF3A		; c635  cd 3a bf	M:?
	JR	NC,XC635	; c638  30 fb		0{
	CALL	XBF61		; c63a  cd 61 bf	Ma?
	CALL	RESTORE_RECT		; c63d  cd 3e c0	M>@
	LD	A,(XBDF6)	; c640  3a f6 bd	:v=
	OR	A		; c643  b7		7
	JR	NZ,XC649	; c644  20 03		 .
	CALL	SET_BRIGHT_FIELD		; c646  cd c4 d3	MDS
XC649:	LD	A,(XBDF6)	; c649  3a f6 bd	:v=
	CP	1		; c64c  fe 01		~.
	RET			; c64e  c9		I
;

; --- Death handler ---
DEATH_HANDLER:	LD	DE,XFF70	; c64f  11 70 ff	.p.
	CALL	XBB20		; c652  cd 20 bb	M ;
	CALL	XC710		; c655  cd 10 c7	M.G
XC658:	CALL	CHECK_COLLISIONS		; c658  cd a9 ca	M)J
	JR	NC,XC66D	; c65b  30 10		0.
	LD	IX,CHASER1_DATA	; c65d  dd 21 28 b0	]!(0
	CALL	MOVE_CHASER		; c661  cd 03 cb	M.K
	LD	IX,CHASER2_DATA	; c664  dd 21 4d b0	]!M0
	CALL	MOVE_CHASER		; c668  cd 03 cb	M.K
	JR	XC658		; c66b  18 eb		.k
;
XC66D:	LD	HL,LIVES	; c66d  21 c2 b0	!B0
	DEC	(HL)		; c670  35		5
	JP	NZ,RESTART_LEVEL	; c671  c2 77 c3	BwC

; --- Game over ---
GAME_OVER:
	CALL	RESET_BRIGHT_FIELD		; c674  cd d3 d3	MSS
	LD	BC,X0B08	; c677  01 08 0b	...
	LD	DE,X0510	; c67a  11 10 05	...
	LD	A,68H		; c67d  3e 68		>h
	CALL	DRAW_BORDERED_RECT		; c67f  cd 70 bf	Mp?
	LD	HL,XC69D	; c682  21 9d c6	!.F
	CALL	STRING_RENDERER		; c685  cd 26 bc	M&<
	LD	BC,X0B08	; c688  01 08 0b	...
	LD	DE,X0510	; c68b  11 10 05	...
	CALL	RAINBOW_CYCLE		; c68e  cd 15 d4	M.T
	CALL	SCORE_FINALIZE		; c691  cd f6 c6	MvF
	CALL	XBAB1		; c694  cd b1 ba	M1:
	CALL	RESTORE_RECT		; c697  cd 3e c0	M>@
	JP	XC6F2		; c69a  c3 f2 c6	CrF
;
XC69D:	DB	1EH,68H,1FH,60H,0DH			; c69d .h.`.
	DB	'Game Over'				; c6a2
	DB	0					; c6ab .
XC6AC:	DB	1EH,68H,1FH,5EH,0DH			; c6ac .h.^.
	DB	'Out of Time'				; c6b1
	DB	1FH,60H,0FH				; c6bc .`.
	DB	'Game Over'				; c6bf
	DB	0					; c6c8 .
;

; --- Out of time ---
OUT_OF_TIME:	CALL	RESET_BRIGHT_FIELD		; c6c9  cd d3 d3	MSS
	LD	BC,X0B08	; c6cc  01 08 0b	...
	LD	DE,X0710	; c6cf  11 10 07	...
	LD	A,68H		; c6d2  3e 68		>h
	CALL	DRAW_BORDERED_RECT		; c6d4  cd 70 bf	Mp?
	LD	HL,XC6AC	; c6d7  21 ac c6	!,F
	CALL	STRING_RENDERER		; c6da  cd 26 bc	M&<
	LD	BC,X0B08	; c6dd  01 08 0b	...
	LD	DE,X0710	; c6e0  11 10 07	...
	CALL	RAINBOW_CYCLE		; c6e3  cd 15 d4	M.T
	CALL	SCORE_FINALIZE		; c6e6  cd f6 c6	MvF
	CALL	XBAB1		; c6e9  cd b1 ba	M1:
	CALL	RESTORE_RECT		; c6ec  cd 3e c0	M>@
	JP	XC6F2		; c6ef  c3 f2 c6	CrF
;
XC6F2:	CALL	XB4FC		; c6f2  cd fc b4	M|4
	RET			; c6f5  c9		I
;

; --- Score finalize ---
SCORE_FINALIZE:	LD	HL,FILL_PERCENT	; c6f6  21 c6 b0	!F0
	LD	A,(HL)		; c6f9  7e		~
	LD	(HL),0		; c6fa  36 00		6.
	LD	HL,RAW_PERCENT	; c6fc  21 c5 b0	!E0
	ADD	A,(HL)		; c6ff  86		.
	LD	(HL),0		; c700  36 00		6.
	LD	L,A		; c702  6f		o
	LD	H,0		; c703  26 00		&.
	ADD	HL,HL		; c705  29		)
	ADD	HL,HL		; c706  29		)
	LD	DE,(BASE_SCORE)	; c707  ed 5b c3 b0	m[C0
	ADD	HL,DE		; c70b  19		.
;
	DB	22H					; c70c "
	DW	BASE_SCORE		; c70d   c3 b0      C0
;
	DB	0C9H					; c70f I
;
XC710:	LD	HL,CHASER2_DATA	; c710  21 4d b0	!M0
	CALL	RESTORE_SPRITE_BG		; c713  cd e5 d0	MeP
	LD	HL,CHASER1_DATA	; c716  21 28 b0	!(0
	CALL	RESTORE_SPRITE_BG		; c719  cd e5 d0	MeP
	LD	HL,TRAIL_CURSOR	; c71c  21 72 b0	!r0
	CALL	RESTORE_SPRITE_BG		; c71f  cd e5 d0	MeP
	LD	HL,PLAYER_XY	; c722  21 03 b0	!.0
	CALL	RESTORE_SPRITE_BG		; c725  cd e5 d0	MeP
	LD	HL,XB099	; c728  21 99 b0	!.0
	LD	B,8		; c72b  06 08		..
;
	DB	'^#V####'				; c72d
	DB	0C5H,0E5H,3EH,0,0CDH,0AEH		; c734 Ee>.M.
	DW	XE1CE		; c73a   ce e1      Na
;
	DB	0C1H,10H				; c73c A.
	DW	X21EE		; c73e   ee 21      n!
;
	DB	0E1H,0B0H				; c740 a0
	DW	X7ECB		; c742   cb 7e      K~
;
	DB	28H,39H					; c744 (9
	DW	XBECB		; c746   cb be      K>
;
	DB	6,3,48H,0DH,21H,0,90H,7EH		; c748 ..H.!..~
	DB	0B7H,28H,0FH				; c750 7(.
	DB	'_#V##y'				; c753
	DB	0C5H,0E5H,0CDH				; c759 EeM
	DW	XCEB1		; c75c   b1 ce      1N
;
	DB	0E1H,0C1H,18H				; c75e aA.
	DW	X3EED		; c761   ed 3e      m>
	DB	8					; c763 .
	DW	X48CD		; c764   cd 48      MH
	DW	X10BB		; c766   bb 10      ;.
;
	DB	0E1H,21H,0,90H,36H,0,22H,0E6H		; c768 a!..6."f
	DB	0B0H,2AH,0E4H,0B0H,22H,3,0B0H,3EH	; c770 0*d0".0>
	DB	0,32H,72H,0B0H,32H			; c778 .2r02
	DW	TRAIL_FRAME_CTR		; c77d   e8 b0      h0
;
	DB	0C9H					; c77f I
;

; --- Calc percentage ---
CALC_PERCENTAGE:	CALL	XCDE8		; c780  cd e8 cd	MhM
	LD	B,H		; c783  44		D
	LD	C,L		; c784  4d		M
	LD	DE,X005A	; c785  11 5a 00	.Z.
	CALL	XD14F		; c788  cd 4f d1	MOQ
	LD	HL,RAW_PERCENT	; c78b  21 c5 b0	!E0
	LD	(HL),C		; c78e  71		q
	CALL	XCDBC		; c78f  cd bc cd	M<M
	LD	DE,X018C	; c792  11 8c 01	...
	OR	A		; c795  b7		7
	SBC	HL,DE		; c796  ed 52		mR
	LD	B,H		; c798  44		D
	LD	C,L		; c799  4d		M
	LD	DE,X005A	; c79a  11 5a 00	.Z.
	CALL	XD14F		; c79d  cd 4f d1	MOQ
	LD	HL,FILL_PERCENT	; c7a0  21 c6 b0	!F0
	LD	(HL),C		; c7a3  71		q
	LD	A,C		; c7a4  79		y
	CP	4BH		; c7a5  fe 4b		~K
	JR	C,XC7AE		; c7a7  38 05		8.
	LD	HL,STATE_FLAGS	; c7a9  21 c8 b0	!H0
	SET	2,(HL)		; c7ac  cb d6		KV
XC7AE:	CALL	UPDATE_PERCENT_DISPLAY		; c7ae  cd a3 d2	M#R
	CALL	UPDATE_SCORE_DISPLAY		; c7b1  cd 7a d2	MzR
	RET			; c7b4  c9		I
;
