; ==========================================================================
; INPUT, ATTRIBUTES & SCREEN UTILITIES ($BA68-$C03D)
; ==========================================================================
;
; This section contains low-level utility routines used throughout the game:
;
; KEYBOARD INPUT ($BA68):
;   Reads ZX Spectrum keyboard ports and encodes as 5-bit value:
;     bit 0 = Fire (Space)
;     bit 1 = Down
;     bit 2 = Up
;     bit 3 = Right
;     bit 4 = Left
;
; ATTRIBUTE ROUTINES:
;   $BAE7  COMPUTE_ATTR_ADDR - converts (row,col) to attr address
;          Input: B=row (0-23), C=col (0-31)
;          Output: HL = $5800 + B*32 + C
;   $BAF6  FILL_ATTR_RECT - fills rectangular attr area
;          Input: B=row, C=col, D=height, E=width, A=attribute byte
;   $BB48  FRAME_DELAY - waits A frames (A x HALT instructions)
;
; STRING RENDERING:
;   $BC26  STRING_RENDERER - renders control strings with embedded
;          position and color commands. Control bytes:
;            $1E xx  = set attribute to xx
;            $1F xx yy = set position (X pixel, Y char row)
;            $00 = end of string
;            Other = ASCII character
;
; RECTANGLE DRAWING:
;   $BF70  DRAW_BORDERED_RECT - draws rectangle with 1px black border
;          Saves background for later restore. Used by level complete
;          popup, game over overlay, and pause screen.
;   $C03E  RESTORE_RECT - undoes bordered rectangle, restoring bitmap/attrs
;

;

; --- Read keyboard ---
READ_KEYBOARD:	LD	HL,XBACE	; ba68  21 ce ba	!N:
	LD	BC,X0500	; ba6b  01 00 05	...
XBA6E:	LD	A,(HL)		; ba6e  7e		~
	RRA			; ba6f  1f		.
	RRA			; ba70  1f		.
	AND	1EH		; ba71  e6 1e		f.
	LD	E,A		; ba73  5f		_
	LD	D,0		; ba74  16 00		..
	LD	A,(HL)		; ba76  7e		~
	INC	HL		; ba77  23		#
	PUSH	HL		; ba78  e5		e
	LD	HL,XBABC	; ba79  21 bc ba	!<:
	ADD	HL,DE		; ba7c  19		.
	LD	D,A		; ba7d  57		W
	PUSH	BC		; ba7e  c5		E
	LD	C,(HL)		; ba7f  4e		N
	INC	HL		; ba80  23		#
	LD	B,(HL)		; ba81  46		F
	IN	A,(C)		; ba82  ed 78		mx
	INC	B		; ba84  04		.
	DEC	B		; ba85  05		.
	JR	Z,XBA89		; ba86  28 01		(.
	CPL			; ba88  2f		/
XBA89:	LD	E,A		; ba89  5f		_
	POP	BC		; ba8a  c1		A
	POP	HL		; ba8b  e1		a
	LD	A,D		; ba8c  7a		z
	AND	7		; ba8d  e6 07		f.
	JR	Z,XBA96		; ba8f  28 05		(.
XBA91:	RR	E		; ba91  cb 1b		K.
	DEC	A		; ba93  3d		=
	JR	NZ,XBA91	; ba94  20 fb		 {
XBA96:	RR	E		; ba96  cb 1b		K.
	RL	C		; ba98  cb 11		K.
	DJNZ	XBA6E		; ba9a  10 d2		.R
	RET			; ba9c  c9		I
;
XBA9D:	LD	A,7FH		; ba9d  3e 7f		>.
	IN	A,(0FEH)	; ba9f  db fe		[~
	RRA			; baa1  1f		.
	RET	C		; baa2  d8		X
	LD	A,0FEH		; baa3  3e fe		>~
	IN	A,(0FEH)	; baa5  db fe		[~
	RRA			; baa7  1f		.
	RET			; baa8  c9		I
;
XBAA9:	CALL	READ_KEYBOARD		; baa9  cd 68 ba	Mh:
	BIT	0,C		; baac  cb 41		KA
	JR	NZ,XBAA9	; baae  20 f9		 y
	RET			; bab0  c9		I
;
XBAB1:	CALL	XBAA9		; bab1  cd a9 ba	M):
XBAB4:	CALL	READ_KEYBOARD		; bab4  cd 68 ba	Mh:
	BIT	0,C		; bab7  cb 41		KA
	JR	Z,XBAB4		; bab9  28 f9		(y
	RET			; babb  c9		I
;
XBABC:	DW	XF7FE		; babc   fe f7      ~w
	DW	XFBFE		; babe   fe fb      ~{
	DW	XFDFE		; bac0   fe fd      ~}
	DW	XFEFE		; bac2   fe fe      ~~
	DW	XEFFE		; bac4   fe ef      ~o
	DW	XDFFE		; bac6   fe df      ~_
	DW	XBFFE		; bac8   fe bf      ~?
	DW	X7FFE		; baca   fe 7f      ~.
;
	DB	1FH,0					; bacc ..
XBACE:	DB	29H					; bace )
XBACF:	DB	28H,11H,1AH				; bacf (..
	DB	'8'					; bad2
Xbad3:	DB	'A@CBD'					; bad3
	DB	4					; bad8 .
	DB	'"#$ $#!'				; bad9
	DB	22H,20H					; bae0 " 
XBAE2:	DB	29H,28H,11H,1AH,38H			; bae2 )(..8
;

; --- Compute attr addr ---
COMPUTE_ATTR_ADDR:	LD	A,B		; bae7  78		x
	ADD	A,A		; bae8  87		.
	ADD	A,A		; bae9  87		.
	ADD	A,A		; baea  87		.
	LD	L,A		; baeb  6f		o
	LD	H,16H		; baec  26 16		&.
	ADD	HL,HL		; baee  29		)
	ADD	HL,HL		; baef  29		)
	LD	A,B		; baf0  78		x
	LD	B,0		; baf1  06 00		..
	ADD	HL,BC		; baf3  09		.
	LD	B,A		; baf4  47		G
	RET			; baf5  c9		I
;

; --- Fill attr rectangle ---
FILL_ATTR_RECT:	EX	AF,AF'		; baf6  08		.
	CALL	COMPUTE_ATTR_ADDR		; baf7  cd e7 ba	Mg:
	EX	AF,AF'		; bafa  08		.
	LD	C,A		; bafb  4f		O
XBAFC:	PUSH	HL		; bafc  e5		e
	LD	B,E		; bafd  43		C
	LD	A,C		; bafe  79		y
XBAFF:	LD	(HL),A		; baff  77		w
	INC	L		; bb00  2c		,
	DJNZ	XBAFF		; bb01  10 fc		.|
	POP	HL		; bb03  e1		a
	LD	A,20H		; bb04  3e 20		> 
	ADD	A,L		; bb06  85		.
	LD	L,A		; bb07  6f		o
	LD	A,H		; bb08  7c		|
	ADC	A,0		; bb09  ce 00		N.
	LD	H,A		; bb0b  67		g
	DEC	D		; bb0c  15		.
	JP	NZ,XBAFC	; bb0d  c2 fc ba	B|:
	RET			; bb10  c9		I
;
XBB11:	LD	DE,X0A05	; bb11  11 05 0a	...
	JR	XBB20		; bb14  18 0a		..
;
	DB	11H,8,60H,18H,5,11H,7FH,40H		; bb16 ..`....@
	DB	18H,0					; bb1e ..
;
XBB20:	LD	A,(XB0ED)	; bb20  3a ed b0	:m0
	RRA			; bb23  1f		.
	RET	NC		; bb24  d0		P
	LD	A,(XB0EB)	; bb25  3a eb b0	:k0
XBB28:	OUT	(0FEH),A	; bb28  d3 fe		S~
	XOR	10H		; bb2a  ee 10		n.
	EX	AF,AF'		; bb2c  08		.
	CALL	PRNG		; bb2d  cd e4 d3	MdS
	AND	7FH		; bb30  e6 7f		f.
	ADD	A,E		; bb32  83		.
	LD	B,A		; bb33  47		G
XBB34:	DJNZ	XBB34		; bb34  10 fe		.~
	EX	AF,AF'		; bb36  08		.
	DEC	D		; bb37  15		.
	JR	NZ,XBB28	; bb38  20 ee		 n
	RET			; bb3a  c9		I
;
XBB3B:	OR	A		; bb3b  b7		7
	RET	Z		; bb3c  c8		H
	PUSH	BC		; bb3d  c5		E
	LD	B,A		; bb3e  47		G
XBB3F:	LD	A,(HL)		; bb3f  7e		~
	INC	HL		; bb40  23		#
	OR	A		; bb41  b7		7
	JR	NZ,XBB3F	; bb42  20 fb		 {
	DJNZ	XBB3F		; bb44  10 f9		.y
	POP	BC		; bb46  c1		A
	RET			; bb47  c9		I
;

; --- Frame delay ---
FRAME_DELAY:	PUSH	BC		; bb48  c5		E
	LD	B,A		; bb49  47		G
XBB4A:	HALT			; bb4a  76		v
;
	DJNZ	XBB4A		; bb4b  10 fd		.}
	POP	BC		; bb4d  c1		A
	RET			; bb4e  c9		I
;
XBB4F:	DB	1					; bb4f .
XBB50:	DB	0F8H					; bb50 x
;
XBB51:	PUSH	AF		; bb51  f5		u
	PUSH	BC		; bb52  c5		E
	PUSH	DE		; bb53  d5		U
	PUSH	HL		; bb54  e5		e
	PUSH	IX		; bb55  dd e5		]e
	DI			; bb57  f3		s
	LD	HL,XBB4F	; bb58  21 4f bb	!O;
	RES	7,(HL)		; bb5b  cb be		K>
	LD	HL,XBB50	; bb5d  21 50 bb	!P;
	INC	(HL)		; bb60  34		4
	POP	IX		; bb61  dd e1		]a
	POP	HL		; bb63  e1		a
	POP	DE		; bb64  d1		Q
	POP	BC		; bb65  c1		A
	POP	AF		; bb66  f1		q
	EI			; bb67  fb		{
	RET			; bb68  c9		I
;
XBB69:	LD	HL,XBB4F	; bb69  21 4f bb	!O;
	SET	7,(HL)		; bb6c  cb fe		K~
XBB6E:	BIT	7,(HL)		; bb6e  cb 7e		K~
	JR	NZ,XBB6E	; bb70  20 fc		 |
	LD	C,80H		; bb72  0e 80		..
	CALL	XBDF7		; bb74  cd f7 bd	Mw=
	LD	BC,(XBDF0)	; bb77  ed 4b f0 bd	mKp=
	LD	(XBDEE),BC	; bb7b  ed 43 ee bd	mCn=
	SRL	B		; bb7f  cb 38		K8
	SRL	B		; bb81  cb 38		K8
	SRL	B		; bb83  cb 38		K8
	SRL	C		; bb85  cb 39		K9
	SRL	C		; bb87  cb 39		K9
	SRL	C		; bb89  cb 39		K9
	CALL	XBD9C		; bb8b  cd 9c bd	M.=
	LD	C,0		; bb8e  0e 00		..
	CALL	XBDF7		; bb90  cd f7 bd	Mw=
	CALL	XBE41		; bb93  cd 41 be	MA>
	RET			; bb96  c9		I
;
	ORG	0BB99H
;
	DB	3FH,0,1FH,0,0FH,80H,6			; bb99 ?......
	DW	X0060		; bba0   60 00      `.
;
	DB	18H,0,6,0				; bba2 ....
;
	ORG	0BBA8H
;
	DB	7FH,80H,7FH				; bba8 ...
	DW	X7FC0		; bbab   c0 7f      @.
;
	DB	0E0H,1FH				; bbad `.
	DW	X07F0		; bbaf   f0 07      p.
;
	DB	0F9H,81H				; bbb1 y.
	DW	XE0FF		; bbb3   ff e0      .`
	DW	XF9FF		; bbb5   ff f9      .y
;
;
XBBB7:	NOP			; bbb7  00		.
;
	ORG	0BBCFH
;
	DB	0DDH,21H,0A9H				; bbcf ]!)
	DW	X6FBC		; bbd2   bc 6f      <o
;
	DB	26H,0,18H,10H				; bbd4 &...
;
XBBD8:	LD	IX,XBCA9	; bbd8  dd 21 a9 bc	]!)<
	LD	DE,X2710	; bbdc  11 10 27	..'
	CALL	XBBFB		; bbdf  cd fb bb	M{;
	LD	DE,X03E8	; bbe2  11 e8 03	.h.
	CALL	XBBFB		; bbe5  cd fb bb	M{;
	LD	DE,X0064	; bbe8  11 64 00	.d.
	CALL	XBBFB		; bbeb  cd fb bb	M{;
	LD	DE,X000A	; bbee  11 0a 00	...
	CALL	XBBFB		; bbf1  cd fb bb	M{;
	LD	A,L		; bbf4  7d		}
	ADD	A,80H		; bbf5  c6 80		F.
	CALL	XBCB5		; bbf7  cd b5 bc	M5<
	RET			; bbfa  c9		I
;
XBBFB:	LD	A,7FH		; bbfb  3e 7f		>.
XBBFD:	INC	A		; bbfd  3c		<
	SBC	HL,DE		; bbfe  ed 52		mR
	JR	NC,XBBFD	; bc00  30 fb		0{
	ADD	HL,DE		; bc02  19		.
	CALL	XBCB5		; bc03  cd b5 bc	M5<
	RET			; bc06  c9		I
;

; --- Process attr color ---
PROCESS_ATTR_COLOR:	PUSH	HL		; bc07  e5		e
	LD	HL,XB0EE	; bc08  21 ee b0	!n0
	BIT	7,(HL)		; bc0b  cb 7e		K~
	JR	NZ,XBC24	; bc0d  20 15		 .
	LD	L,A		; bc0f  6f		o
	AND	0C0H		; bc10  e6 c0		f@
	LD	H,A		; bc12  67		g
	LD	A,L		; bc13  7d		}
	AND	7		; bc14  e6 07		f.
	CP	2		; bc16  fe 02		~.
	CCF			; bc18  3f		?
	SBC	A,A		; bc19  9f		.
	LD	L,A		; bc1a  6f		o
	AND	7		; bc1b  e6 07		f.
	OR	H		; bc1d  b4		4
	LD	H,A		; bc1e  67		g
	LD	A,L		; bc1f  7d		}
	CPL			; bc20  2f		/
	AND	38H		; bc21  e6 38		f8
	OR	H		; bc23  b4		4
XBC24:	POP	HL		; bc24  e1		a
	RET			; bc25  c9		I
;

; --- String renderer ---
STRING_RENDERER:	LD	IX,XBCA9	; bc26  dd 21 a9 bc	]!)<
XBC2A:	LD	A,(HL)		; bc2a  7e		~
	INC	HL		; bc2b  23		#
	OR	A		; bc2c  b7		7
	RET	Z		; bc2d  c8		H
	CP	20H		; bc2e  fe 20		~ 
	JR	C,XBC37		; bc30  38 05		8.
	CALL	XBCB5		; bc32  cd b5 bc	M5<
	JR	XBC2A		; bc35  18 f3		.s
;
XBC37:	CP	1EH		; bc37  fe 1e		~.
	JR	Z,XBC4B		; bc39  28 10		(.
	JR	C,XBC55		; bc3b  38 18		8.
	LD	A,(HL)		; bc3d  7e		~
	LD	(IX+0),A	; bc3e  dd 77 00	]w.
	INC	HL		; bc41  23		#
	LD	A,(HL)		; bc42  7e		~
	AND	7FH		; bc43  e6 7f		f.
	LD	(IX+1),A	; bc45  dd 77 01	]w.
	INC	HL		; bc48  23		#
	JR	XBC2A		; bc49  18 df		._
;
XBC4B:	LD	A,(HL)		; bc4b  7e		~
	CALL	PROCESS_ATTR_COLOR		; bc4c  cd 07 bc	M.<
	LD	(IX+2),A	; bc4f  dd 77 02	]w.
	INC	HL		; bc52  23		#
	JR	XBC2A		; bc53  18 d5		.U
;
XBC55:	CP	1CH		; bc55  fe 1c		~.
	JR	Z,XBC71		; bc57  28 18		(.
	JR	C,XBC7F		; bc59  38 24		8$
	LD	A,(IX+0)	; bc5b  dd 7e 00	]~.
	AND	7		; bc5e  e6 07		f.
	JR	Z,XBC2A		; bc60  28 c8		(H
	LD	A,7EH		; bc62  3e 7e		>~
	CALL	XBCB5		; bc64  cd b5 bc	M5<
	LD	A,(IX+0)	; bc67  dd 7e 00	]~.
	AND	0F8H		; bc6a  e6 f8		fx
	LD	(IX+0),A	; bc6c  dd 77 00	]w.
	JR	XBC2A		; bc6f  18 b9		.9
;
XBC71:	LD	B,(HL)		; bc71  46		F
	INC	HL		; bc72  23		#
	LD	C,(HL)		; bc73  4e		N
	INC	HL		; bc74  23		#
	PUSH	HL		; bc75  e5		e
XBC76:	LD	A,C		; bc76  79		y
	CALL	XBCB5		; bc77  cd b5 bc	M5<
	DJNZ	XBC76		; bc7a  10 fa		.z
	POP	HL		; bc7c  e1		a
	JR	XBC2A		; bc7d  18 ab		.+
;
XBC7F:	CP	8		; bc7f  fe 08		~.
	JR	NZ,XBC8D	; bc81  20 0a		 .
	LD	A,(IX+0)	; bc83  dd 7e 00	]~.
	SUB	8		; bc86  d6 08		V.
	LD	(IX+0),A	; bc88  dd 77 00	]w.
	JR	XBC2A		; bc8b  18 9d		..
;
XBC8D:	CP	9		; bc8d  fe 09		~.
	JR	NZ,XBC9B	; bc8f  20 0a		 .
	LD	A,(IX+0)	; bc91  dd 7e 00	]~.
	ADD	A,8		; bc94  c6 08		F.
	LD	(IX+0),A	; bc96  dd 77 00	]w.
	JR	XBC2A		; bc99  18 8f		..
;
XBC9B:	CP	0AH		; bc9b  fe 0a		~.
	JR	NZ,XBCA4	; bc9d  20 05		 .
	INC	(IX+1)		; bc9f  dd 34 01	]4.
	JR	XBC2A		; bca2  18 86		..
;
XBCA4:	DEC	(IX+1)		; bca4  dd 35 01	]5.
	JR	XBC2A		; bca7  18 81		..
;
XBCA9:	PUSH	BC		; bca9  c5		E
XBCAA:	RLA			; bcaa  17		.
	LD	B,A		; bcab  47		G
XBCAC:	NOP			; bcac  00		.
	ADD	A,B		; bcad  80		.
	RET	NZ		; bcae  c0		@
	RET	PO		; bcaf  e0		`
	RET	P		; bcb0  f0		p
	RET	M		; bcb1  f8		x
	CALL	M,XFFFE		; bcb2  fc fe ff	|~.
XBCB5:	PUSH	BC		; bcb5  c5		E
	PUSH	DE		; bcb6  d5		U
	PUSH	HL		; bcb7  e5		e
	LD	E,A		; bcb8  5f		_
	LD	D,0		; bcb9  16 00		..
	LD	HL,XC0D5	; bcbb  21 d5 c0	!U@
	ADD	HL,DE		; bcbe  19		.
	LD	A,(HL)		; bcbf  7e		~
	LD	B,A		; bcc0  47		G
	LD	HL,XBCAC	; bcc1  21 ac bc	!,<
	ADD	A,L		; bcc4  85		.
	LD	L,A		; bcc5  6f		o
	ADC	A,H		; bcc6  8c		.
	SUB	L		; bcc7  95		.
	LD	H,A		; bcc8  67		g
	LD	A,(HL)		; bcc9  7e		~
	CPL			; bcca  2f		/
	LD	C,A		; bccb  4f		O
	LD	L,(IX+1)	; bccc  dd 6e 01	]n.
	LD	H,0		; bccf  26 00		&.
	ADD	HL,HL		; bcd1  29		)
	ADD	HL,HL		; bcd2  29		)
	ADD	HL,HL		; bcd3  29		)
	ADD	HL,HL		; bcd4  29		)
	LD	A,0FCH		; bcd5  3e fc		>|
;
	DB	84H					; bcd7 .
	DB	'g~#fo'					; bcd8
	DB	0DDH,7EH,0,1FH,1FH,1FH,0E6H,1FH		; bcdd ]~....f.
	DB	85H,6FH					; bce5 .o
	DW	X29EB		; bce7   eb 29      k)
;
	DB	29H,29H,3EH,0F6H,84H,67H		; bce9 ))>v.g
	DW	XC5EB		; bcef   eb c5      kE
;
	DB	6,8,1AH,0DDH,0CBH,2,7EH,28H		; bcf1 ...]K.~(
	DB	2					; bcf9 .
	DW	X2FB1		; bcfa   b1 2f      1/
;
	DB	13H,0C5H				; bcfc .E
	DW	X5FD5		; bcfe   d5 5f      U_
;
	DB	16H,0,6,0FFH,0DDH,7EH,0,0E6H		; bd00 ....]~.f
	DB	7,28H,0CH				; bd08 .(.
	DW	X3BCB		; bd0b   cb 3b      K;
	DW	X1ACB		; bd0d   cb 1a      K.
	DB	37H					; bd0f 7
	DW	X19CB		; bd10   cb 19      K.
	DW	X18CB		; bd12   cb 18      K.
;
	DB	3DH,20H,0F4H,79H,0A6H,0B3H,77H,23H	; bd14 = ty&3w#
	DB	78H,0A6H				; bd1c x&
	DW	X77B2		; bd1e   b2 77      2w
;
	DB	2BH,24H					; bd20 +$
	DW	XC1D1		; bd22   d1 c1      QA
	DB	10H					; bd24 .
	DW	XC1CD		; bd25   cd c1      MA
;
	DB	0DDH,7EH,1,87H,87H,87H,6FH,26H		; bd27 ]~....o&
	DB	16H,29H,29H,0DDH,7EH,0,1FH,1FH		; bd2f .))]~...
	DB	1FH,0E6H,1FH,85H,6FH,0DDH,5EH,2		; bd37 .f..o]^.
	DW	XBBCB		; bd3f   cb bb      K;
;
	DB	73H,0DDH,7EH,0,0E6H,7,80H		; bd41 s]~.f..
	DW	X09FE		; bd48   fe 09      ~.
;
	DB	38H,2,23H,73H,0DDH,7EH,0		; bd4a 8.#s]~.
;
	ADD	A,B		; bd51  80		.
	LD	(IX+0),A	; bd52  dd 77 00	]w.
	JR	NC,XBD61	; bd55  30 0a		0.
	LD	A,(IX+1)	; bd57  dd 7e 01	]~.
	CP	17H		; bd5a  fe 17		~.
	ADC	A,0		; bd5c  ce 00		N.
	LD	(IX+1),A	; bd5e  dd 77 01	]w.
XBD61:	POP	HL		; bd61  e1		a
	POP	DE		; bd62  d1		Q
	POP	BC		; bd63  c1		A
	RET			; bd64  c9		I
;
XBD65:	PUSH	BC		; bd65  c5		E
	PUSH	DE		; bd66  d5		U
	PUSH	HL		; bd67  e5		e
	LD	C,A		; bd68  4f		O
	LD	L,D		; bd69  6a		j
	LD	H,0		; bd6a  26 00		&.
	ADD	HL,HL		; bd6c  29		)
	ADD	HL,HL		; bd6d  29		)
	ADD	HL,HL		; bd6e  29		)
	ADD	HL,HL		; bd6f  29		)
	LD	A,0FCH		; bd70  3e fc		>|
	ADD	A,H		; bd72  84		.
	LD	H,A		; bd73  67		g
	LD	A,E		; bd74  7b		{
	ADD	A,(HL)		; bd75  86		.
	INC	HL		; bd76  23		#
	LD	H,(HL)		; bd77  66		f
	LD	L,A		; bd78  6f		o
	LD	B,8		; bd79  06 08		..
XBD7B:	PUSH	BC		; bd7b  c5		E
	PUSH	HL		; bd7c  e5		e
	LD	A,(HL)		; bd7d  7e		~
	XOR	7FH		; bd7e  ee 7f		n.
	LD	(HL),A		; bd80  77		w
	LD	B,C		; bd81  41		A
	DEC	B		; bd82  05		.
	JR	Z,XBD8F		; bd83  28 0a		(.
	INC	HL		; bd85  23		#
	DEC	B		; bd86  05		.
	JR	Z,XBD8F		; bd87  28 06		(.
XBD89:	LD	A,(HL)		; bd89  7e		~
	CPL			; bd8a  2f		/
	LD	(HL),A		; bd8b  77		w
	INC	HL		; bd8c  23		#
	DJNZ	XBD89		; bd8d  10 fa		.z
XBD8F:	LD	A,(HL)		; bd8f  7e		~
	XOR	0FEH		; bd90  ee fe		n~
	LD	(HL),A		; bd92  77		w
	POP	HL		; bd93  e1		a
	INC	H		; bd94  24		$
	POP	BC		; bd95  c1		A
	DJNZ	XBD7B		; bd96  10 e3		.c
	POP	HL		; bd98  e1		a
	POP	DE		; bd99  d1		Q
	POP	BC		; bd9a  c1		A
	RET			; bd9b  c9		I
;
XBD9C:	LD	IX,(XBDF4)	; bd9c  dd 2a f4 bd	]*t=
XBDA0:	LD	A,(IX+0)	; bda0  dd 7e 00	]~.
	CP	0FFH		; bda3  fe ff		~.
	RET	Z		; bda5  c8		H
	JP	M,XBDC8		; bda6  fa c8 bd	zH=
	LD	E,A		; bda9  5f		_
	LD	A,B		; bdaa  78		x
	CP	(IX+1)		; bdab  dd be 01	]>.
	JR	NZ,XBDE7	; bdae  20 37		 7
	LD	A,C		; bdb0  79		y
	SUB	E		; bdb1  93		.
	JR	C,XBDE7		; bdb2  38 33		83
	CP	(IX+2)		; bdb4  dd be 02	]>.
	JR	NC,XBDE7	; bdb7  30 2e		0.
	LD	D,(IX+1)	; bdb9  dd 56 01	]V.
	LD	A,(IX+2)	; bdbc  dd 7e 02	]~.
	SET	7,(IX+0)	; bdbf  dd cb 00 fe	]K.~
	CALL	XBD65		; bdc3  cd 65 bd	Me=
	JR	XBDE7		; bdc6  18 1f		..
;
XBDC8:	AND	7FH		; bdc8  e6 7f		f.
	LD	E,A		; bdca  5f		_
	LD	A,B		; bdcb  78		x
	CP	(IX+1)		; bdcc  dd be 01	]>.
	JR	NZ,XBDDA	; bdcf  20 09		 .
	LD	A,C		; bdd1  79		y
	SUB	E		; bdd2  93		.
	JR	C,XBDDA		; bdd3  38 05		8.
	CP	(IX+2)		; bdd5  dd be 02	]>.
	JR	C,XBDE7		; bdd8  38 0d		8.
XBDDA:	RES	7,(IX+0)	; bdda  dd cb 00 be	]K.>
	LD	D,(IX+1)	; bdde  dd 56 01	]V.
	LD	A,(IX+2)	; bde1  dd 7e 02	]~.
	CALL	XBD65		; bde4  cd 65 bd	Me=
XBDE7:	LD	DE,X0003	; bde7  11 03 00	...
	ADD	IX,DE		; bdea  dd 19		].
	JR	XBDA0		; bdec  18 b2		.2
;
XBDEE:	DW	XA0C8		; bdee   c8 a0      H 
;
XBDF0:	DB	0					; bdf0 .
;
	ORG	0BDF2H
;
XBDF2:	NOP			; bdf2  00		.
XBDF3:	NOP			; bdf3  00		.
XBDF4:	NOP			; bdf4  00		.
;
	ORG	0BDF6H
;
XBDF6:	RST	38H		; bdf6  ff		.
XBDF7:	LD	HL,XBDEE	; bdf7  21 ee bd	!n=
	LD	A,(HL)		; bdfa  7e		~
	RRA			; bdfb  1f		.
	RRA			; bdfc  1f		.
	RRA			; bdfd  1f		.
	AND	1FH		; bdfe  e6 1f		f.
	OR	C		; be00  b1		1
	LD	C,A		; be01  4f		O
	INC	HL		; be02  23		#
	LD	A,0C0H		; be03  3e c0		>@
	SUB	(HL)		; be05  96		.
	RET	Z		; be06  c8		H
	RET	C		; be07  d8		X
	CP	8		; be08  fe 08		~.
	JR	C,XBE0E		; be0a  38 02		8.
	LD	A,8		; be0c  3e 08		>.
XBE0E:	LD	B,A		; be0e  47		G
	LD	L,(HL)		; be0f  6e		n
	LD	H,0		; be10  26 00		&.
	ADD	HL,HL		; be12  29		)
	EX	DE,HL		; be13  eb		k
	LD	IX,ROW_PTR_TABLE	; be14  dd 21 00 fc	]!.|
	ADD	IX,DE		; be18  dd 19		].
	LD	DE,XBBB7	; be1a  11 b7 bb	.7;
XBE1D:	LD	A,C		; be1d  79		y
	AND	1FH		; be1e  e6 1f		f.
	ADD	A,(IX+0)	; be20  dd 86 00	]..
	LD	L,A		; be23  6f		o
	INC	IX		; be24  dd 23		]#
	LD	H,(IX+0)	; be26  dd 66 00	]f.
	INC	IX		; be29  dd 23		]#
	BIT	7,C		; be2b  cb 79		Ky
	JR	Z,XBE30		; be2d  28 01		(.
	EX	DE,HL		; be2f  eb		k
XBE30:	LDI			; be30  ed a0		m 
	LDI			; be32  ed a0		m 
	LDI			; be34  ed a0		m 
	INC	BC		; be36  03		.
	INC	BC		; be37  03		.
	INC	BC		; be38  03		.
	BIT	7,C		; be39  cb 79		Ky
	JR	Z,XBE3E		; be3b  28 01		(.
	EX	DE,HL		; be3d  eb		k
XBE3E:	DJNZ	XBE1D		; be3e  10 dd		.]
	RET			; be40  c9		I
;
XBE41:	LD	HL,XBDEE	; be41  21 ee bd	!n=
	LD	C,(HL)		; be44  4e		N
	INC	HL		; be45  23		#
	LD	A,0C0H		; be46  3e c0		>@
	SUB	(HL)		; be48  96		.
	RET	Z		; be49  c8		H
	RET	C		; be4a  d8		X
	CP	8		; be4b  fe 08		~.
	JR	C,XBE51		; be4d  38 02		8.
	LD	A,8		; be4f  3e 08		>.
XBE51:	LD	B,A		; be51  47		G
	LD	A,(HL)		; be52  7e		~
	ADD	A,A		; be53  87		.
	LD	L,A		; be54  6f		o
	ADC	A,0FCH		; be55  ce fc		N|
	SUB	L		; be57  95		.
	LD	H,A		; be58  67		g
	LD	IX,XBB97	; be59  dd 21 97 bb	]!.;
XBE5D:	PUSH	BC		; be5d  c5		E
	LD	A,C		; be5e  79		y
	RRA			; be5f  1f		.
	RRA			; be60  1f		.
	RRA			; be61  1f		.
	AND	1FH		; be62  e6 1f		f.
;
	DB	86H					; be64 .
	DB	'_~#V#'					; be65
	DB	0B2H,28H,49H,0E5H			; be6a 2(Ie
	DW	XE5EB		; be6e   eb e5      ke
;
	DB	79H,0DDH,46H,0,0DDH,56H,1,26H		; be70 y]F.]V.&
	DB	0,0DDH,4EH,10H,0DDH,5EH,11H,2EH		; be78 .]N.]^..
;
	RST	38H		; be80  ff		.
	AND	7		; be81  e6 07		f.
	JR	Z,XBE95		; be83  28 10		(.
XBE85:	SRL	B		; be85  cb 38		K8
	RR	D		; be87  cb 1a		K.
	RR	H		; be89  cb 1c		K.
	SCF			; be8b  37		7
	RR	C		; be8c  cb 19		K.
	RR	E		; be8e  cb 1b		K.
	RR	L		; be90  cb 1d		K.
	DEC	A		; be92  3d		=
	JR	NZ,XBE85	; be93  20 f0		 p
XBE95:	EX	(SP),HL		; be95  e3		c
	LD	A,C		; be96  79		y
	AND	(HL)		; be97  a6		&
	OR	B		; be98  b0		0
	LD	(HL),A		; be99  77		w
	INC	HL		; be9a  23		#
	LD	A,L		; be9b  7d		}
	AND	1FH		; be9c  e6 1f		f.
	JR	Z,XBEB0		; be9e  28 10		(.
	LD	A,E		; bea0  7b		{
	AND	(HL)		; bea1  a6		&
	OR	D		; bea2  b2		2
	LD	(HL),A		; bea3  77		w
	INC	HL		; bea4  23		#
	LD	A,L		; bea5  7d		}
	AND	1FH		; bea6  e6 1f		f.
	JR	Z,XBEB0		; bea8  28 06		(.
	POP	DE		; beaa  d1		Q
	PUSH	DE		; beab  d5		U
	LD	A,E		; beac  7b		{
	AND	(HL)		; bead  a6		&
	OR	D		; beae  b2		2
	LD	(HL),A		; beaf  77		w
XBEB0:	POP	DE		; beb0  d1		Q
	INC	IX		; beb1  dd 23		]#
	INC	IX		; beb3  dd 23		]#
	POP	HL		; beb5  e1		a
	POP	BC		; beb6  c1		A
	DJNZ	XBE5D		; beb7  10 a4		.$
	RET			; beb9  c9		I
;
XBEBA:	CALL	READ_KEYBOARD		; beba  cd 68 ba	Mh:
	LD	A,(XBDF3)	; bebd  3a f3 bd	:s=
	INC	A		; bec0  3c		<
	LD	D,A		; bec1  57		W
	LD	HL,XBDF2	; bec2  21 f2 bd	!r=
	LD	A,C		; bec5  79		y
	CP	(HL)		; bec6  be		>
	JR	Z,XBECB		; bec7  28 02		(.
	LD	D,0		; bec9  16 00		..
XBECB:	LD	(HL),A		; becb  77		w
	LD	A,D		; becc  7a		z
	LD	(XBDF3),A	; becd  32 f3 bd	2s=
	LD	D,1		; bed0  16 01		..
	CP	0CH		; bed2  fe 0c		~.
	JR	C,XBEE1		; bed4  38 0b		8.
	INC	D		; bed6  14		.
	CP	10H		; bed7  fe 10		~.
	JR	C,XBEE1		; bed9  38 06		8.
	INC	D		; bedb  14		.
	CP	14H		; bedc  fe 14		~.
	JR	C,XBEE1		; bede  38 01		8.
	INC	D		; bee0  14		.
XBEE1:	LD	HL,(XBDEE)	; bee1  2a ee bd	*n=
	BIT	4,C		; bee4  cb 61		Ka
	JR	Z,XBEEE		; bee6  28 06		(.
	LD	A,L		; bee8  7d		}
	SUB	D		; bee9  92		.
	JR	NC,XBEED	; beea  30 01		0.
	XOR	A		; beec  af		/
XBEED:	LD	L,A		; beed  6f		o
XBEEE:	BIT	3,C		; beee  cb 59		KY
	JR	Z,XBEFD		; bef0  28 0b		(.
	LD	A,L		; bef2  7d		}
	ADD	A,D		; bef3  82		.
	JR	C,XBEFA		; bef4  38 04		8.
	CP	0FCH		; bef6  fe fc		~|
	JR	C,XBEFC		; bef8  38 02		8.
XBEFA:	LD	A,0FCH		; befa  3e fc		>|
XBEFC:	LD	L,A		; befc  6f		o
XBEFD:	BIT	2,C		; befd  cb 51		KQ
	JR	Z,XBF07		; beff  28 06		(.
	LD	A,H		; bf01  7c		|
	SUB	D		; bf02  92		.
	JR	NC,XBF06	; bf03  30 01		0.
	XOR	A		; bf05  af		/
XBF06:	LD	H,A		; bf06  67		g
XBF07:	BIT	1,C		; bf07  cb 49		KI
	JR	Z,XBF14		; bf09  28 09		(.
	LD	A,H		; bf0b  7c		|
	ADD	A,D		; bf0c  82		.
	CP	0BEH		; bf0d  fe be		~>
	JR	C,XBF13		; bf0f  38 02		8.
	LD	A,0BEH		; bf11  3e be		>>
XBF13:	LD	H,A		; bf13  67		g
XBF14:	LD	(XBDF0),HL	; bf14  22 f0 bd	"p=
	RET			; bf17  c9		I
;
XBF18:	LD	(XBDF4),HL	; bf18  22 f4 bd	"t=
	LD	BC,(XBDEE)	; bf1b  ed 4b ee bd	mKn=
	SRL	B		; bf1f  cb 38		K8
	SRL	B		; bf21  cb 38		K8
	SRL	B		; bf23  cb 38		K8
	SRL	C		; bf25  cb 39		K9
	SRL	C		; bf27  cb 39		K9
	SRL	C		; bf29  cb 39		K9
	CALL	XBD9C		; bf2b  cd 9c bd	M.=
	CALL	XBAA9		; bf2e  cd a9 ba	M):
	LD	C,0		; bf31  0e 00		..
	CALL	XBDF7		; bf33  cd f7 bd	Mw=
	CALL	XBE41		; bf36  cd 41 be	MA>
	RET			; bf39  c9		I
;
XBF3A:	CALL	XBEBA		; bf3a  cd ba be	M:>
	LD	A,C		; bf3d  79		y
	OR	A		; bf3e  b7		7
	RET	Z		; bf3f  c8		H
	CALL	XBB69		; bf40  cd 69 bb	Mi;
	LD	A,(XBDF2)	; bf43  3a f2 bd	:r=
	RRA			; bf46  1f		.
	RET	NC		; bf47  d0		P
	LD	HL,(XBDF4)	; bf48  2a f4 bd	*t=
	LD	DE,X0003	; bf4b  11 03 00	...
	LD	C,0		; bf4e  0e 00		..
XBF50:	LD	A,(HL)		; bf50  7e		~
	CP	0FFH		; bf51  fe ff		~.
	RET	Z		; bf53  c8		H
	JP	M,XBF5B		; bf54  fa 5b bf	z[?
	ADD	HL,DE		; bf57  19		.
	INC	C		; bf58  0c		.
	JR	XBF50		; bf59  18 f5		.u
;
XBF5B:	LD	A,C		; bf5b  79		y
	LD	(XBDF6),A	; bf5c  32 f6 bd	2v=
	SCF			; bf5f  37		7
	RET			; bf60  c9		I
;
XBF61:	LD	C,80H		; bf61  0e 80		..
	CALL	XBDF7		; bf63  cd f7 bd	Mw=
	LD	BC,X8080	; bf66  01 80 80	...
	CALL	XBD9C		; bf69  cd 9c bd	M.=
	CALL	XBB11		; bf6c  cd 11 bb	M.;
	RET			; bf6f  c9		I
;

; --- Draw bordered rect ---
DRAW_BORDERED_RECT:	CALL	PROCESS_ATTR_COLOR		; bf70  cd 07 bc	M.<
	LD	(XC0B8),A	; bf73  32 b8 c0	28@
	LD	(XC0B9),BC	; bf76  ed 43 b9 c0	mC9@
	LD	(XC0BB),DE	; bf7a  ed 53 bb c0	mS;@
	LD	A,B		; bf7e  78		x
	RLA			; bf7f  17		.
	RLA			; bf80  17		.
	RLA			; bf81  17		.
	AND	0F8H		; bf82  e6 f8		fx
	LD	C,A		; bf84  4f		O
	LD	B,0		; bf85  06 00		..
	LD	IX,ROW_PTR_TABLE	; bf87  dd 21 00 fc	]!.|
	ADD	IX,BC		; bf8b  dd 09		].
	ADD	IX,BC		; bf8d  dd 09		].
	LD	A,D		; bf8f  7a		z
	RLA			; bf90  17		.
	RLA			; bf91  17		.
	RLA			; bf92  17		.
	AND	0F8H		; bf93  e6 f8		fx
	SUB	2		; bf95  d6 02		V.
	LD	B,A		; bf97  47		G
	LD	C,E		; bf98  4b		K
	LD	HL,(XC0BD)	; bf99  2a bd c0	*=@
	LD	E,(HL)		; bf9c  5e		^
	INC	HL		; bf9d  23		#
	LD	D,(HL)		; bf9e  56		V
	LD	A,(XC0B9)	; bf9f  3a b9 c0	:9@
	ADD	A,(IX+0)	; bfa2  dd 86 00	]..
	LD	L,A		; bfa5  6f		o
	INC	IX		; bfa6  dd 23		]#
	LD	H,(IX+0)	; bfa8  dd 66 00	]f.
	INC	IX		; bfab  dd 23		]#
	PUSH	BC		; bfad  c5		E
	LD	B,C		; bfae  41		A
XBFAF:	LD	A,(HL)		; bfaf  7e		~
	LD	(DE),A		; bfb0  12		.
	LD	(HL),0FFH	; bfb1  36 ff		6.
	INC	HL		; bfb3  23		#
	INC	DE		; bfb4  13		.
	DJNZ	XBFAF		; bfb5  10 f8		.x
	POP	BC		; bfb7  c1		A
XBFB8:	PUSH	BC		; bfb8  c5		E
	LD	B,C		; bfb9  41		A
	DEC	B		; bfba  05		.
	DEC	B		; bfbb  05		.
	LD	A,(XC0B9)	; bfbc  3a b9 c0	:9@
	ADD	A,(IX+0)	; bfbf  dd 86 00	]..
	LD	L,A		; bfc2  6f		o
	INC	IX		; bfc3  dd 23		]#
	LD	H,(IX+0)	; bfc5  dd 66 00	]f.
	INC	IX		; bfc8  dd 23		]#
	LD	A,(HL)		; bfca  7e		~
	LD	(DE),A		; bfcb  12		.
	LD	(HL),80H	; bfcc  36 80		6.
	INC	HL		; bfce  23		#
	INC	DE		; bfcf  13		.
XBFD0:	LD	A,(HL)		; bfd0  7e		~
	LD	(DE),A		; bfd1  12		.
	LD	(HL),0		; bfd2  36 00		6.
	INC	HL		; bfd4  23		#
	INC	DE		; bfd5  13		.
	DJNZ	XBFD0		; bfd6  10 f8		.x
	LD	A,(HL)		; bfd8  7e		~
	LD	(DE),A		; bfd9  12		.
	LD	(HL),1		; bfda  36 01		6.
	INC	DE		; bfdc  13		.
	POP	BC		; bfdd  c1		A
	DJNZ	XBFB8		; bfde  10 d8		.X
	LD	A,(XC0B9)	; bfe0  3a b9 c0	:9@
	ADD	A,(IX+0)	; bfe3  dd 86 00	]..
	LD	L,A		; bfe6  6f		o
	INC	IX		; bfe7  dd 23		]#
	LD	H,(IX+0)	; bfe9  dd 66 00	]f.
	LD	B,C		; bfec  41		A
XBFED:	LD	A,(HL)		; bfed  7e		~
	LD	(DE),A		; bfee  12		.
XBFEF:	LD	(HL),0FFH	; bfef  36 ff		6.
	INC	HL		; bff1  23		#
	INC	DE		; bff2  13		.
	DJNZ	XBFED		; bff3  10 f8		.x
	LD	BC,(XC0B9)	; bff5  ed 4b b9 c0	mK9@
	LD	L,B		; bff9  68		h
	LD	H,0		; bffa  26 00		&.
	ADD	HL,HL		; bffc  29		)
	ADD	HL,HL		; bffd  29		)
XBFFE:	ADD	HL,HL		; bffe  29		)
	ADD	HL,HL		; bfff  29		)
	ADD	HL,HL		; c000  29		)
	LD	B,58H		; c001  06 58		.X
	ADD	HL,BC		; c003  09		.
	LD	BC,(XC0BB)	; c004  ed 4b bb c0	mK;@
XC008:	PUSH	BC		; c008  c5		E
	PUSH	HL		; c009  e5		e
	LD	B,C		; c00a  41		A
	LD	A,(XC0B8)	; c00b  3a b8 c0	:8@
	LD	C,A		; c00e  4f		O
XC00F:	LD	A,(HL)		; c00f  7e		~
	LD	(DE),A		; c010  12		.
	LD	(HL),C		; c011  71		q
	INC	HL		; c012  23		#
	INC	DE		; c013  13		.
	DJNZ	XC00F		; c014  10 f9		.y
	POP	HL		; c016  e1		a
	LD	BC,X0020	; c017  01 20 00	. .
	ADD	HL,BC		; c01a  09		.
	POP	BC		; c01b  c1		A
	DJNZ	XC008		; c01c  10 ea		.j
	LD	HL,(XC0BD)	; c01e  2a bd c0	*=@
	INC	HL		; c021  23		#
	INC	HL		; c022  23		#
	LD	BC,(XC0B9)	; c023  ed 4b b9 c0	mK9@
	LD	(HL),C		; c027  71		q
	INC	HL		; c028  23		#
	LD	(HL),B		; c029  70		p
	INC	HL		; c02a  23		#
	LD	BC,(XC0BB)	; c02b  ed 4b bb c0	mK;@
	LD	(HL),C		; c02f  71		q
	INC	HL		; c030  23		#
	LD	(HL),B		; c031  70		p
	INC	HL		; c032  23		#
	LD	(XC0BD),HL	; c033  22 bd c0	"=@
	LD	(HL),E		; c036  73		s
	INC	HL		; c037  23		#
	LD	(HL),D		; c038  72		r
	LD	HL,XC0B7	; c039  21 b7 c0	!7@
	INC	(HL)		; c03c  34		4
	RET			; c03d  c9		I
;
