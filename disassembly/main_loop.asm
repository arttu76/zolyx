; ==========================================================================
; MAIN GAME LOOP & LEVEL COMPLETE ($C371-$C616)
; ==========================================================================
;
; GAME ENTRY ($C371):
;   Called from menu system. Sets up for first level.
;   $C374: CALL $CC5A (LEVEL_INIT) then fall through to main loop.
;   $C377: Restart level after death (entities reset, grid preserved).
;
; MAIN LOOP ($C3DC):
;   Executes once per frame, synchronized to 50Hz via HALT.
;   Order of operations each frame:
;     1. Increment frame counter
;     2. HALT (wait for vertical blank)
;     3. Erase all entities at old positions
;     4. Erase/redraw sparks
;     5. If drawing, redraw trail cell at player position
;     6. Process player movement ($C7B5)
;     7. Store entity backgrounds for sprite drawing
;     8. Check spark positions for trail collision
;     9. Draw sparks at new positions
;    10. Draw entities: player, cursor, chasers
;    11. Play sounds based on state flags
;    12. Check player-enemy collisions ($CAA9)
;    13. Move chaser 1 ($CB03), chaser 2 ($CB03)
;    14. Move all 8 sparks ($D18A x 8)
;    15. Move trail cursor ($CBFE)
;    16. Decrement timer (sub-counter at $B0E9, main at $B0C0)
;    17. Update score display ($D27A)
;    18. Update timer bar ($D2C1)
;    19. Check pause key ($C617)
;    20. Check state flags:
;        bit 1 set -> timer expired -> death/game over
;        bit 0 set -> collision -> lose life
;        bit 2 set -> level complete (>=75%) -> next level
;        none set -> loop back to $C3DC
;
; LEVEL COMPLETE ($C55D):
;   Triggered when filled percentage >= 75%. Sequence:
;     1. Dim field (clear BRIGHT bit on all field attributes)
;     2. Draw popup rectangle at rows 11-15, cols 8-23 (bright cyan)
;     3. Print "Screen Completed" text in popup
;     4. Rainbow color cycling: 16 steps x 2 frames = 640ms
;        Cycles PAPER through all 8 colors twice
;     5. Finalize percentage into score: score += (raw% + fill%) * 4
;     6. Sync timer bar display to actual value
;     7. Timer-to-score countdown: each remaining timer tick = +1 point
;        Animated: timer bar shrinks, score increments, 40ms per tick
;        Max duration: 176 ticks x 40ms = ~7 seconds
;     8. Post-countdown pause: 50 frames = 1.0 second
;     9. Restore screen (undo popup)
;    10. Increment level number, jump to LEVEL_INIT
;
; STRINGS embedded after code:
;   $C5BB: "Screen Completed" (with position/color control bytes)
;   $C5D1: "All Screens Completed" (unused/dead code)
;   $C5EC: "Game Paused" / "Continue" / "Abort" (pause menu)
;


; --- Game entry ---
GAME_ENTRY:
	DW	X40CD		; c371   cd 40      M@
;
	DB	0CCH					; c373 L
;

; --- Level start ---
LEVEL_START:	CALL	LEVEL_INIT		; c374  cd 5a cc	MZL

; --- Restart level ---
RESTART_LEVEL:	LD	HL,X9000	; c377  21 00 90	!..
	LD	(HL),0		; c37a  36 00		6.
	LD	(TRAIL_WRITE_PTR),HL	; c37c  22 e6 b0	"f0
	LD	A,0		; c37f  3e 00		>.
	LD	(STATE_FLAGS),A	; c381  32 c8 b0	2H0
	CALL	UPDATE_LIVES_DISPLAY		; c384  cd b0 d2	M0R
	LD	HL,PLAYER_XY	; c387  21 03 b0	!.0
	CALL	SAVE_SPRITE_BG		; c38a  cd ac d0	M,P
	LD	HL,TRAIL_CURSOR	; c38d  21 72 b0	!r0
	CALL	SAVE_SPRITE_BG		; c390  cd ac d0	M,P
	LD	HL,CHASER1_DATA	; c393  21 28 b0	!(0
	CALL	SAVE_SPRITE_BG		; c396  cd ac d0	M,P
	LD	HL,CHASER2_DATA	; c399  21 4d b0	!M0
	CALL	SAVE_SPRITE_BG		; c39c  cd ac d0	M,P
	LD	HL,PLAYER_XY	; c39f  21 03 b0	!.0
	CALL	DRAW_MASKED_SPRITE		; c3a2  cd 78 d0	MxP
	LD	HL,TRAIL_CURSOR	; c3a5  21 72 b0	!r0
	CALL	DRAW_MASKED_SPRITE		; c3a8  cd 78 d0	MxP
	LD	HL,CHASER1_DATA	; c3ab  21 28 b0	!(0
	CALL	DRAW_MASKED_SPRITE		; c3ae  cd 78 d0	MxP
	LD	HL,CHASER2_DATA	; c3b1  21 4d b0	!M0
	CALL	DRAW_MASKED_SPRITE		; c3b4  cd 78 d0	MxP
	LD	HL,XB099	; c3b7  21 99 b0	!.0
	LD	B,8		; c3ba  06 08		..
;
Xc3bc:	DB	'^#V####'				; c3bc
;
XC3C3:	PUSH	BC		; c3c3  c5		E
	PUSH	HL		; c3c4  e5		e
	LD	A,3		; c3c5  3e 03		>.
	CALL	WRITE_CELL_BMP		; c3c7  cd ae ce	M.N
	POP	HL		; c3ca  e1		a
	POP	BC		; c3cb  c1		A
	DJNZ	XC3BC		; c3cc  10 ee		.n
	LD	BC,X0018	; c3ce  01 18 00	...
	LD	DE,X0208	; c3d1  11 08 02	...
	CALL	XD3F3		; c3d4  cd f3 d3	MsS
	LD	A,32H		; c3d7  3e 32		>2
	CALL	FRAME_DELAY		; c3d9  cd 48 bb	MH;

; --- Main loop ---
MAIN_LOOP:	LD	IX,PLAYER_FLAGS	; c3dc  dd 21 e1 b0	]!a0
	LD	HL,FRAME_CTR	; c3e0  21 c7 b0	!G0
	INC	(HL)		; c3e3  34		4
	HALT			; c3e4  76		v
;
	LD	HL,CHASER2_DATA	; c3e5  21 4d b0	!M0
	CALL	RESTORE_SPRITE_BG		; c3e8  cd e5 d0	MeP
	LD	HL,CHASER1_DATA	; c3eb  21 28 b0	!(0
	CALL	RESTORE_SPRITE_BG		; c3ee  cd e5 d0	MeP
	LD	HL,TRAIL_CURSOR	; c3f1  21 72 b0	!r0
	CALL	RESTORE_SPRITE_BG		; c3f4  cd e5 d0	MeP
	LD	HL,PLAYER_XY	; c3f7  21 03 b0	!.0
	CALL	RESTORE_SPRITE_BG		; c3fa  cd e5 d0	MeP
	LD	DE,(XB099)	; c3fd  ed 5b 99 b0	m[.0
	XOR	A		; c401  af		/
	CALL	WRITE_CELL_BMP		; c402  cd ae ce	M.N
	LD	DE,(XB09E)	; c405  ed 5b 9e b0	m[.0
	XOR	A		; c409  af		/
	CALL	WRITE_CELL_BMP		; c40a  cd ae ce	M.N
	LD	DE,(XB0A3)	; c40d  ed 5b a3 b0	m[#0
	XOR	A		; c411  af		/
	CALL	WRITE_CELL_BMP		; c412  cd ae ce	M.N
	LD	DE,(XB0A8)	; c415  ed 5b a8 b0	m[(0
	XOR	A		; c419  af		/
	CALL	WRITE_CELL_BMP		; c41a  cd ae ce	M.N
	LD	DE,(XB0AD)	; c41d  ed 5b ad b0	m[-0
	XOR	A		; c421  af		/
	CALL	WRITE_CELL_BMP		; c422  cd ae ce	M.N
	LD	DE,(XB0B2)	; c425  ed 5b b2 b0	m[20
	XOR	A		; c429  af		/
	CALL	WRITE_CELL_BMP		; c42a  cd ae ce	M.N
	LD	DE,(XB0B7)	; c42d  ed 5b b7 b0	m[70
	XOR	A		; c431  af		/
	CALL	WRITE_CELL_BMP		; c432  cd ae ce	M.N
	LD	DE,(XB0BC)	; c435  ed 5b bc b0	m[<0
	XOR	A		; c439  af		/
	CALL	WRITE_CELL_BMP		; c43a  cd ae ce	M.N
	BIT	7,(IX+0)	; c43d  dd cb 00 7e	]K.~
	JR	Z,XC44C		; c441  28 09		(.
	LD	DE,(PLAYER_XY)	; c443  ed 5b 03 b0	m[.0
	LD	A,3		; c447  3e 03		>.
	CALL	XCEB1		; c449  cd b1 ce	M1N
XC44C:	CALL	PLAYER_MOVEMENT		; c44c  cd b5 c7	M5G
	LD	HL,PLAYER_XY	; c44f  21 03 b0	!.0
	CALL	SAVE_SPRITE_BG		; c452  cd ac d0	M,P
	LD	HL,TRAIL_CURSOR	; c455  21 72 b0	!r0
	CALL	SAVE_SPRITE_BG		; c458  cd ac d0	M,P
	LD	HL,CHASER1_DATA	; c45b  21 28 b0	!(0
	CALL	SAVE_SPRITE_BG		; c45e  cd ac d0	M,P
	LD	HL,CHASER2_DATA	; c461  21 4d b0	!M0
	CALL	SAVE_SPRITE_BG		; c464  cd ac d0	M,P
	LD	HL,SPARK_ARRAY	; c467  21 97 b0	!.0
	LD	B,8		; c46a  06 08		..
;
	DB	'^#V####'				; c46c
	DB	1CH,1DH,28H,18H,0C5H,0E5H		; c473 ..(.Ee
	DW	XDBCD		; c479   cd db      M[
	DB	0CEH					; c47b N
	DW	X03FE		; c47c   fe 03      ~.
;
	DB	20H,0DH					; c47e  .
	DW	XECCB		; c480   cb ec      Kl
	DW	XDECD		; c482   cd de      M^
	DW	XB7CE		; c484   ce b7      N7
;
	DB	20H,5,21H				; c486  .!
	DW	STATE_FLAGS		; c489   c8 b0      H0
	DW	XC6CB		; c48b   cb c6      KF
;
	DB	0E1H,0C1H				; c48d aA
	DW	X10D5		; c48f   d5 10      U.
;
	DB	0DAH,6,8,0D9H				; c491 Z..Y
	DW	X3ED1		; c495   d1 3e      Q>
;
	DB	3,0CDH,0AEH				; c497 .M.
	DW	XD9CE		; c49a   ce d9      NY
;
	DB	10H,0F6H,21H,3,0B0H			; c49c .v!.0
	DW	X78CD		; c4a1   cd 78      Mx
	DW	X21D0		; c4a3   d0 21      P!
;
	DB	72H,0B0H				; c4a5 r0
	DW	X78CD		; c4a7   cd 78      Mx
	DW	X21D0		; c4a9   d0 21      P!
;
	DB	28H,0B0H				; c4ab (0
	DW	X78CD		; c4ad   cd 78      Mx
	DW	X21D0		; c4af   d0 21      P!
;
	DB	4DH,0B0H				; c4b1 M0
	DW	X78CD		; c4b3   cd 78      Mx
	DW	X21D0		; c4b5   d0 21      P!
	DW	STATE_FLAGS		; c4b7   c8 b0      H0
	DW	X76CB		; c4b9   cb 76      Kv
;
	DB	28H,0AH					; c4bb (.
	DW	XB6CB		; c4bd   cb b6      K6
;
	DB	11H,1,4					; c4bf ...
	DW	X20CD		; c4c2   cd 20      M 
;
	DB	0BBH,18H,0CH				; c4c4 ;..
	DW	X7ECB		; c4c7   cb 7e      K~
;
	DB	28H,8					; c4c9 (.
	DW	XBECB		; c4cb   cb be      K>
;
	DB	11H,0AH,2				; c4cd ...
	DW	X20CD		; c4d0   cd 20      M 
	DB	0BBH					; c4d2 ;
	DW	XA9CD		; c4d3   cd a9      M)
	DW	X30CA		; c4d5   ca 30      J0
;
	DB	5,21H					; c4d7 .!
	DW	STATE_FLAGS		; c4d9   c8 b0      H0
	DW	XC6CB		; c4db   cb c6      KF
;
	DB	0DDH,21H,28H,0B0H			; c4dd ]!(0
	DW	X03CD		; c4e1   cd 03      M.
	DW	XDDCB		; c4e3   cb dd      K]
;
	DB	21H,4DH,0B0H				; c4e5 !M0
	DW	X03CD		; c4e8   cd 03      M.
	DW	XDDCB		; c4ea   cb dd      K]
;
	DB	21H,97H,0B0H,0CDH,8AH			; c4ec !.0M.
	DW	XDDD1		; c4f1   d1 dd      Q]
;
	DB	21H,9CH,0B0H,0CDH,8AH			; c4f3 !.0M.
	DW	XDDD1		; c4f8   d1 dd      Q]
;
	DB	21H,0A1H,0B0H,0CDH,8AH			; c4fa !!0M.
	DW	XDDD1		; c4ff   d1 dd      Q]
;
	DB	21H,0A6H,0B0H,0CDH			; c501 !&0M
;
	ADC	A,D		; c505  8a		.
	POP	DE		; c506  d1		Q
	LD	IX,XB0AB	; c507  dd 21 ab b0	]!+0
	CALL	MOVE_SPARK		; c50b  cd 8a d1	M.Q
	LD	IX,XB0B0	; c50e  dd 21 b0 b0	]!00
	CALL	MOVE_SPARK		; c512  cd 8a d1	M.Q
	LD	IX,XB0B5	; c515  dd 21 b5 b0	]!50
	CALL	MOVE_SPARK		; c519  cd 8a d1	M.Q
	LD	IX,XB0BA	; c51c  dd 21 ba b0	]!:0
	CALL	MOVE_SPARK		; c520  cd 8a d1	M.Q
	LD	IX,TRAIL_CURSOR	; c523  dd 21 72 b0	]!r0
	CALL	MOVE_TRAIL_CURSOR		; c527  cd fe cb	M~K
	LD	HL,TIMER_SUB_CTR	; c52a  21 e9 b0	!i0
	DEC	(HL)		; c52d  35		5
	JR	NZ,XC53F	; c52e  20 0f		 .
	LD	A,(TIMER_SPEED)	; c530  3a ea b0	:j0
	LD	(HL),A		; c533  77		w
	LD	HL,GAME_TIMER	; c534  21 c0 b0	!@0
	DEC	(HL)		; c537  35		5
	JR	NZ,XC53F	; c538  20 05		 .
	LD	HL,STATE_FLAGS	; c53a  21 c8 b0	!H0
	SET	1,(HL)		; c53d  cb ce		KN
XC53F:	CALL	UPDATE_SCORE_DISPLAY		; c53f  cd 7a d2	MzR
	CALL	UPDATE_TIMER_BAR		; c542  cd c1 d2	MAR
	CALL	CHECK_PAUSE		; c545  cd 17 c6	M.F
	JP	NC,XC6F2	; c548  d2 f2 c6	RrF
	LD	HL,STATE_FLAGS	; c54b  21 c8 b0	!H0
	BIT	1,(HL)		; c54e  cb 4e		KN
	JP	NZ,OUT_OF_TIME	; c550  c2 c9 c6	BIF
	BIT	0,(HL)		; c553  cb 46		KF
	JP	NZ,DEATH_HANDLER	; c555  c2 4f c6	BOF
	BIT	2,(HL)		; c558  cb 56		KV
	JP	Z,MAIN_LOOP		; c55a  ca dc c3	J\C

; --- Level complete ---
LEVEL_COMPLETE:
	CALL	RESET_BRIGHT_FIELD		; c55d  cd d3 d3	MSS
	LD	BC,X0B08	; c560  01 08 0b	...
	LD	DE,X0510	; c563  11 10 05	...
	LD	A,68H		; c566  3e 68		>h
	CALL	DRAW_BORDERED_RECT		; c568  cd 70 bf	Mp?
	LD	HL,XC5BB	; c56b  21 bb c5	!;E
	CALL	STRING_RENDERER		; c56e  cd 26 bc	M&<
	LD	BC,X0B08	; c571  01 08 0b	...
	LD	DE,X0510	; c574  11 10 05	...
	CALL	RAINBOW_CYCLE		; c577  cd 15 d4	M.T
	CALL	SCORE_FINALIZE		; c57a  cd f6 c6	MvF
XC57D:	CALL	UPDATE_TIMER_BAR		; c57d  cd c1 d2	MAR
	JR	C,XC57D		; c580  38 fb		8{
	LD	A,(GAME_TIMER)	; c582  3a c0 b0	:@0
	OR	A		; c585  b7		7
	JR	Z,XC5A9		; c586  28 21		(!
	LD	B,A		; c588  47		G
XC589:	PUSH	BC		; c589  c5		E
	LD	HL,GAME_TIMER	; c58a  21 c0 b0	!@0
	DEC	(HL)		; c58d  35		5
	CALL	UPDATE_TIMER_BAR		; c58e  cd c1 d2	MAR
	LD	HL,X0006	; c591  21 06 00	!..
	LD	(SCORE_DISPLAY_POS),HL	; c594  22 12 d3	".S
	LD	HL,(BASE_SCORE)	; c597  2a c3 b0	*C0
	INC	HL		; c59a  23		#
	LD	(BASE_SCORE),HL	; c59b  22 c3 b0	"C0
	CALL	DISPLAY_5DIGIT		; c59e  cd 15 d3	M.S
	LD	A,2		; c5a1  3e 02		>.
	CALL	FRAME_DELAY		; c5a3  cd 48 bb	MH;
	POP	BC		; c5a6  c1		A
	DJNZ	XC589		; c5a7  10 e0		.`
XC5A9:	LD	A,32H		; c5a9  3e 32		>2
	CALL	FRAME_DELAY		; c5ab  cd 48 bb	MH;
	CALL	RESTORE_RECT		; c5ae  cd 3e c0	M>@
	LD	HL,LEVEL_NUM	; c5b1  21 c1 b0	!A0
	INC	(HL)		; c5b4  34		4
	JP	LEVEL_START		; c5b5  c3 74 c3	CtC
;
	DW	XF2C3		; c5b8   c3 f2      Cr
;
	DW	X1EC6		; c5ba   c6 1e      F.
;
	DB	68H,1FH,4BH,0DH				; c5bc h.K.
	DB	'Screen Completed'			; c5c0
	DB	0,1EH,68H,1FH,82H,0DH			; c5d0 ..h...
	DB	'All Screens Completed'			; c5d6
XC5EB:	DB	0					; c5eb .
XC5EC:	DB	1EH,68H,1FH,5AH,0DH			; c5ec .h.Z.
Xc5f1:	DB	'G'					; c5f1
Xc5f2:	DB	'ame'					; c5f2
Xc5f5:	DB	' Paused'				; c5f5
	DB	1FH,4CH,0FH				; c5fc .L.
	DB	'Continue'				; c5ff
	DB	1FH,8CH,0FH,41H,62H,6FH,72H,74H		; c607 ...Abort
	DB	0					; c60f .
;
XC610:	ADD	HL,BC		; c610  09		.
	RRCA			; c611  0f		.
	EX	AF,AF'		; c612  08		.
	LD	DE,X060F	; c613  11 0f 06	...
	RST	38H		; c616  ff		.
