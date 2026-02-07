; ==========================================================================
; VISUAL EFFECTS & PRNG ($D3C4-$D500)
; ==========================================================================
;
; SET_BRIGHT_FIELD ($D3C4):
;   Sets bit 6 (BRIGHT) on all field attributes (rows 4-23).
;   Creates a bright flash effect. Used during fill events.
;
; RESET_BRIGHT_FIELD ($D3D3):
;   Clears bit 6 (BRIGHT) on all field attributes.
;   Used to dim the field during level complete and game over overlays.
;
; PRNG ($D3E4):
;   Pseudo-random number generator. Returns 8-bit value in A.
;   Uses a linear feedback approach on a 16-bit seed.
;   Called during spark initialization (random offsets and directions).
;
; RAINBOW_CYCLE ($D415):
;   Rainbow PAPER cycling animation on a rectangular attribute area.
;   Input: BC=row/col, DE=height/width (same as FILL_ATTR_RECT).
;   Cycles the PAPER color (bits 3-5) through all 8 ZX colors twice:
;     16 iterations x 2 HALT frames = 32 frames = 640ms.
;   Color sequence: cyan->green->yellow->white->black->blue->red->magenta->...
;   INK, BRIGHT, and FLASH bits are preserved.
;

;

; --- Set BRIGHT field ---
SET_BRIGHT_FIELD:	LD	HL,X5880	; d3c4  21 80 58	!.X
	LD	BC,X0280	; d3c7  01 80 02	...
XD3CA:	SET	6,(HL)		; d3ca  cb f6		Kv
	INC	HL		; d3cc  23		#
	DEC	BC		; d3cd  0b		.
	LD	A,B		; d3ce  78		x
	OR	C		; d3cf  b1		1
	JR	NZ,XD3CA	; d3d0  20 f8		 x
	RET			; d3d2  c9		I
;

; --- Reset BRIGHT field ---
RESET_BRIGHT_FIELD:	LD	HL,X5880	; d3d3  21 80 58	!.X
	LD	BC,X0280	; d3d6  01 80 02	...
XD3D9:	RES	6,(HL)		; d3d9  cb b6		K6
	INC	HL		; d3db  23		#
	DEC	BC		; d3dc  0b		.
	LD	A,B		; d3dd  78		x
	OR	C		; d3de  b1		1
	JR	NZ,XD3D9	; d3df  20 f8		 x
	RET			; d3e1  c9		I
;
XD3E2:	DB	8,2					; d3e2 ..
;

; --- PRNG ---
PRNG:	PUSH	HL		; d3e4  e5		e
	LD	HL,(XD3E2)	; d3e5  2a e2 d3	*bS
	INC	HL		; d3e8  23		#
	RES	5,H		; d3e9  cb ac		K,
	LD	(XD3E2),HL	; d3eb  22 e2 d3	"bS
	LD	A,R		; d3ee  ed 5f		m_
	XOR	(HL)		; d3f0  ae		.
	POP	HL		; d3f1  e1		a
	RET			; d3f2  c9		I
;
XD3F3:	CALL	COMPUTE_ATTR_ADDR		; d3f3  cd e7 ba	Mg:
	LD	L,(HL)		; d3f6  6e		n
	LD	H,10H		; d3f7  26 10		&.
XD3F9:	LD	A,L		; d3f9  7d		}
	AND	0F8H		; d3fa  e6 f8		fx
	PUSH	AF		; d3fc  f5		u
	LD	A,L		; d3fd  7d		}
	ADD	A,1		; d3fe  c6 01		F.
	AND	7		; d400  e6 07		f.
	LD	L,A		; d402  6f		o
	POP	AF		; d403  f1		q
	OR	L		; d404  b5		5
	LD	L,A		; d405  6f		o
	PUSH	BC		; d406  c5		E
	PUSH	DE		; d407  d5		U
	PUSH	HL		; d408  e5		e
	HALT			; d409  76		v
;
	HALT			; d40a  76		v
;
	CALL	FILL_ATTR_RECT		; d40b  cd f6 ba	Mv:
	POP	HL		; d40e  e1		a
	POP	DE		; d40f  d1		Q
	POP	BC		; d410  c1		A
	DEC	H		; d411  25		%
	JR	NZ,XD3F9	; d412  20 e5		 e
	RET			; d414  c9		I
;

; --- Rainbow cycle ---
RAINBOW_CYCLE:	CALL	COMPUTE_ATTR_ADDR		; d415  cd e7 ba	Mg:
	LD	L,(HL)		; d418  6e		n
	LD	H,10H		; d419  26 10		&.
XD41B:	LD	A,L		; d41b  7d		}
	AND	0C7H		; d41c  e6 c7		fG
	PUSH	AF		; d41e  f5		u
	LD	A,L		; d41f  7d		}
	ADD	A,8		; d420  c6 08		F.
	AND	38H		; d422  e6 38		f8
	LD	L,A		; d424  6f		o
	POP	AF		; d425  f1		q
	OR	L		; d426  b5		5
	LD	L,A		; d427  6f		o
	PUSH	BC		; d428  c5		E
	PUSH	DE		; d429  d5		U
	PUSH	HL		; d42a  e5		e
	HALT			; d42b  76		v
;
	HALT			; d42c  76		v
;
	CALL	FILL_ATTR_RECT		; d42d  cd f6 ba	Mv:
	POP	HL		; d430  e1		a
	POP	DE		; d431  d1		Q
	POP	BC		; d432  c1		A
	DEC	H		; d433  25		%
	JR	NZ,XD41B	; d434  20 e5		 e
	RET			; d436  c9		I
;
	DB	21H,0,40H,36H,0,11H,1,40H		; d437 !.@6...@
	DB	1,0FFH,17H				; d43f ...
	DW	XB0ED		; d442   ed b0      m0
;
	DB	1,0,0,11H,20H,18H,3EH,30H		; d444 .... .>0
	DW	XF6CD		; d44c   cd f6      Mv
	DW	X21BA		; d44e   ba 21      :!
;
	DB	31H,0DBH,36H,0,11H,32H,0DBH,1		; d450 1[6..2[.
	DB	51H,3					; d458 Q.
	DW	XB0ED		; d45a   ed b0      m0
;
	DB	1,4,4,11H,18H,10H,3EH,70H		; d45c ......>p
	DW	X70CD		; d464   cd 70      Mp
	DW	X21BF		; d466   bf 21      ?!
	DW	XE4B5		; d468   b5 e4      5d
	DW	X26CD		; d46a   cd 26      M&
	DW	X21BC		; d46c   bc 21      <!
;
	DB	2AH,0E5H				; d46e *e
	DW	X18CD		; d470   cd 18      M.
	DW	XCDBF		; d472   bf cd      ?M
	DB	3AH					; d474 :
	DW	X30BF		; d475   bf 30      ?0
	DB	0FBH					; d477 {
	DW	X61CD		; d478   cd 61      Ma
	DW	XCDBF		; d47a   bf cd      ?M
	DB	3EH					; d47c >
	DW	X3AC0		; d47d   c0 3a      @:
	DB	0F6H					; d47f v
	DW	XB7BD		; d480   bd b7      =7
;
	DB	20H,14H,1,0,0,11H,20H,18H		; d482  ..... .
	DB	3EH,46H					; d48a >F
	DW	XF6CD		; d48c   cd f6      Mv
	DW	X21BA		; d48e   ba 21      :!
;
	DB	31H,0E5H				; d490 1e
	DW	X26CD		; d492   cd 26      M&
	DW	XCDBC		; d494   bc cd      <M
	DW	XBAB1		; d496   b1 ba      1:
;
	DB	1,0,0,11H,20H,18H,3EH,30H		; d498 .... .>0
	DW	XF6CD		; d4a0   cd f6      Mv
;
	DB	0BAH,0DDH,21H,10H			; d4a2 :]!.
	DW	X06FC		; d4a6   fc 06      |.
	DB	17H					; d4a8 .
	DW	X11C5		; d4a9   c5 11      E.
;
	DB	0ADH,0E4H,6,8				; d4ab -d..
	DW	X1AC5		; d4af   c5 1a      E.
;
	DB	13H,0DDH,6EH,0,0DDH,23H,0DDH,66H	; d4b1 .]n.]#]f
	DB	0,0DDH,23H,6,20H,77H,2CH,10H		; d4b9 .]#. w,.
	DW	XC1FC		; d4c1   fc c1      |A
	DB	10H					; d4c3 .
	DW	XC1EA		; d4c4   ea c1      jA
;
	DB	10H,0E1H,21H,36H			; d4c6 .a!6
	DW	XCDE2		; d4ca   e2 cd      bM
;
	DB	26H					; d4cc &
;
	CP	H		; d4cd  bc		<
XD4CE:	CALL	XD756		; d4ce  cd 56 d7	MVW
	LD	HL,XE406	; d4d1  21 06 e4	!.d
	CALL	XBF18		; d4d4  cd 18 bf	M.?
XD4D7:	CALL	XBF3A		; d4d7  cd 3a bf	M:?
	JR	C,XD527		; d4da  38 4b		8K
	LD	A,(XBDF2)	; d4dc  3a f2 bd	:r=
	RRA			; d4df  1f		.
	JR	NC,XD4D7	; d4e0  30 f5		0u
	LD	BC,(XBDEE)	; d4e2  ed 4b ee bd	mKn=
	SRL	B		; d4e6  cb 38		K8
	SRL	B		; d4e8  cb 38		K8
	SRL	B		; d4ea  cb 38		K8
	INC	B		; d4ec  04		.
	DEC	B		; d4ed  05		.
	JR	Z,XD4D7		; d4ee  28 e7		(g
	DEC	B		; d4f0  05		.
	SRL	C		; d4f1  cb 39		K9
	SRL	C		; d4f3  cb 39		K9
	SRL	C		; d4f5  cb 39		K9
	LD	L,B		; d4f7  68		h
	LD	H,0		; d4f8  26 00		&.
	ADD	HL,HL		; d4fa  29		)
	ADD	HL,HL		; d4fb  29		)
	ADD	HL,HL		; d4fc  29		)
	ADD	HL,HL		; d4fd  29		)
	PUSH	HL		; d4fe  e5		e
	LD	E,B		; d4ff  58		X
	LD	D,0		; d500  16 00		..
