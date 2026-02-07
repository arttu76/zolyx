; ==========================================================================
; REMAINING CODE & MISCELLANEOUS ($D501-$EFFF)
; ==========================================================================
;
; This area contains additional game routines not fully documented,
; including sound generation, menu graphics, and helper functions.
;

	ADD	HL,DE		; d502  19		.
	ADD	HL,HL		; d503  29		)
	LD	DE,XDB54	; d504  11 54 db	.T[
	ADD	HL,DE		; d507  19		.
	LD	B,0		; d508  06 00		..
	ADD	HL,BC		; d50a  09		.
	LD	A,(XE1E7)	; d50b  3a e7 e1	:ga
	LD	(HL),A		; d50e  77		w
	POP	HL		; d50f  e1		a
	ADD	HL,HL		; d510  29		)
	LD	DE,X5820	; d511  11 20 58	. X
	ADD	HL,DE		; d514  19		.
	ADD	HL,BC		; d515  09		.
	EX	DE,HL		; d516  eb		k
	LD	A,(XE1E7)	; d517  3a e7 e1	:ga
	LD	C,A		; d51a  4f		O
	LD	B,0		; d51b  06 00		..
	LD	HL,XE1E8	; d51d  21 e8 e1	!ha
	ADD	HL,BC		; d520  09		.
	LD	A,(HL)		; d521  7e		~
	OR	38H		; d522  f6 38		v8
	LD	(DE),A		; d524  12		.
	JR	XD4D7		; d525  18 b0		.0
;
XD527:	CALL	XBF61		; d527  cd 61 bf	Ma?
	LD	A,(XBDF6)	; d52a  3a f6 bd	:v=
	CP	4		; d52d  fe 04		~.
	RET	NC		; d52f  d0		P
	ADD	A,A		; d530  87		.
	LD	E,A		; d531  5f		_
	LD	D,0		; d532  16 00		..
	LD	HL,XD541	; d534  21 41 d5	!AU
	ADD	HL,DE		; d537  19		.
	LD	E,(HL)		; d538  5e		^
	INC	HL		; d539  23		#
	LD	D,(HL)		; d53a  56		V
	EX	DE,HL		; d53b  eb		k
	LD	DE,XD4CE	; d53c  11 ce d4	.NT
	PUSH	DE		; d53f  d5		U
	JP	(HL)		; d540  e9		i
;
XD541:	DB	49H					; d541 I
	DW	X01D5		; d542   d5 01      U.
	DW	X60D6		; d544   d6 60      V`
	DW	XC8D6		; d546   d6 c8      VH
	DW	X01D6		; d548   d6 01      V.
;
	DB	0,0,11H,8,0CH,3EH			; d54a .....>
;
	JR	NC,XD51F	; d550  30 cd		0M
	LD	(HL),B		; d552  70		p
	CP	A		; d553  bf		?
	LD	HL,XE3B3	; d554  21 b3 e3	!3c
	CALL	STRING_RENDERER		; d557  cd 26 bc	M&<
XD55A:	LD	IX,XBCA9	; d55a  dd 21 a9 bc	]!)<
	LD	B,4		; d55e  06 04		..
XD560:	LD	A,4		; d560  3e 04		>.
	SUB	B		; d562  90		.
	LD	C,A		; d563  4f		O
	ADD	A,3		; d564  c6 03		F.
	LD	(IX+1),A	; d566  dd 77 01	]w.
	LD	(IX+0),30H	; d569  dd 36 00 30	]6.0
	LD	A,(XE1E6)	; d56d  3a e6 e1	:fa
	CP	C		; d570  b9		9
	LD	A,9EH		; d571  3e 9e		>.
	JR	NZ,XD576	; d573  20 01		 .
	INC	A		; d575  3c		<
XD576:	CALL	XBCB5		; d576  cd b5 bc	M5<
	DJNZ	XD560		; d579  10 e5		.e
	LD	HL,XE49A	; d57b  21 9a e4	!.d
	CALL	XBF18		; d57e  cd 18 bf	M.?
XD581:	CALL	XBF3A		; d581  cd 3a bf	M:?
	JR	NC,XD581	; d584  30 fb		0{
	CALL	XBF61		; d586  cd 61 bf	Ma?
	LD	A,(XBDF6)	; d589  3a f6 bd	:v=
	CP	4		; d58c  fe 04		~.
	JR	NC,XD596	; d58e  30 06		0.
	LD	(XE1E6),A	; d590  32 e6 e1	2fa
	JP	XD55A		; d593  c3 5a d5	CZU
;
XD596:	CALL	RESTORE_RECT		; d596  cd 3e c0	M>@
	LD	A,(XBDF6)	; d599  3a f6 bd	:v=
	CP	5		; d59c  fe 05		~.
	RET	Z		; d59e  c8		H
	LD	HL,XDB31	; d59f  21 31 db	!1[
	LD	DE,XD7DF	; d5a2  11 df d7	._W
	LD	BC,X0352	; d5a5  01 52 03	.R.
	LDIR			; d5a8  ed b0		m0
	LD	C,0		; d5aa  0e 00		..
	CALL	XD7BB		; d5ac  cd bb d7	M;W
	LD	HL,X0000	; d5af  21 00 00	!..
	LD	(XE1EC),HL	; d5b2  22 ec e1	"la
	LD	HL,XE3F7	; d5b5  21 f7 e3	!wc
	CALL	STRING_RENDERER		; d5b8  cd 26 bc	M&<
XD5BB:	CALL	XD780		; d5bb  cd 80 d7	M.W
	LD	C,0		; d5be  0e 00		..
	CALL	XD7BB		; d5c0  cd bb d7	M;W
	LD	HL,XE400	; d5c3  21 00 e4	!.d
	CALL	STRING_RENDERER		; d5c6  cd 26 bc	M&<
	LD	HL,(XE1EC)	; d5c9  2a ec e1	*la
	INC	HL		; d5cc  23		#
	LD	(XE1EC),HL	; d5cd  22 ec e1	"la
	CALL	XBBD8		; d5d0  cd d8 bb	MX;
	LD	A,(XE1E6)	; d5d3  3a e6 e1	:fa
	CP	3		; d5d6  fe 03		~.
	JR	NZ,XD5E8	; d5d8  20 0e		 .
XD5DA:	CALL	XBA9D		; d5da  cd 9d ba	M.:
	JR	NC,XD5F5	; d5dd  30 16		0.
	CALL	READ_KEYBOARD		; d5df  cd 68 ba	Mh:
	BIT	0,C		; d5e2  cb 41		KA
	JR	Z,XD5DA		; d5e4  28 f4		(t
	JR	XD5BB		; d5e6  18 d3		.S
;
XD5E8:	ADD	A,A		; d5e8  87		.
	ADD	A,A		; d5e9  87		.
	ADD	A,A		; d5ea  87		.
	ADD	A,2		; d5eb  c6 02		F.
	CALL	FRAME_DELAY		; d5ed  cd 48 bb	MH;
	CALL	XBA9D		; d5f0  cd 9d ba	M.:
	JR	C,XD5BB		; d5f3  38 c6		8F
XD5F5:	LD	C,38H		; d5f5  0e 38		.8
	CALL	XD7BB		; d5f7  cd bb d7	M;W
	LD	HL,XE236	; d5fa  21 36 e2	!6b
	CALL	STRING_RENDERER		; d5fd  cd 26 bc	M&<
	RET			; d600  c9		I
;
	LD	BC,X0005	; d601  01 05 00	...
	LD	DE,X1208	; d604  11 08 12	...
	LD	A,30H		; d607  3e 30		>0
	CALL	DRAW_BORDERED_RECT		; d609  cd 70 bf	Mp?
	LD	HL,XE264	; d60c  21 64 e2	!db
	CALL	STRING_RENDERER		; d60f  cd 26 bc	M&<
XD612:	LD	HL,XE1D5	; d612  21 d5 e1	!Ua
	LD	B,0DH		; d615  06 0d		..
	LD	IX,XBCA9	; d617  dd 21 a9 bc	]!)<
XD61B:	LD	A,0FH		; d61b  3e 0f		>.
	SUB	B		; d61d  90		.
	LD	(IX+1),A	; d61e  dd 77 01	]w.
	LD	(IX+0),50H	; d621  dd 36 00 50	]6.P
	LD	A,(HL)		; d625  7e		~
	ADD	A,80H		; d626  c6 80		F.
	CALL	XBCB5		; d628  cd b5 bc	M5<
	INC	HL		; d62b  23		#
	DJNZ	XD61B		; d62c  10 ed		.m
	LD	HL,XE416	; d62e  21 16 e4	!.d
	CALL	XBF18		; d631  cd 18 bf	M.?
XD634:	CALL	XBF3A		; d634  cd 3a bf	M:?
	JR	NC,XD634	; d637  30 fb		0{
	CALL	XBF61		; d639  cd 61 bf	Ma?
	LD	A,(XBDF6)	; d63c  3a f6 bd	:v=
	CP	1AH		; d63f  fe 1a		~.
	JR	Z,XD65C		; d641  28 19		(.
	LD	E,A		; d643  5f		_
	RRCA			; d644  0f		.
	CCF			; d645  3f		?
	SBC	A,A		; d646  9f		.
	ADD	A,A		; d647  87		.
	INC	A		; d648  3c		<
	SRL	E		; d649  cb 3b		K;
	LD	D,0		; d64b  16 00		..
	LD	HL,XE1D5	; d64d  21 d5 e1	!Ua
	ADD	HL,DE		; d650  19		.
	ADD	A,(HL)		; d651  86		.
	JP	M,XD612		; d652  fa 12 d6	z.V
	CP	4		; d655  fe 04		~.
	JR	NC,XD612	; d657  30 b9		09
	LD	(HL),A		; d659  77		w
	JR	XD612		; d65a  18 b6		.6
;
XD65C:	CALL	RESTORE_RECT		; d65c  cd 3e c0	M>@
	RET			; d65f  c9		I
;
	LD	BC,X0009	; d660  01 09 00	...
	LD	DE,X090D	; d663  11 0d 09	...
	LD	A,30H		; d666  3e 30		>0
	CALL	DRAW_BORDERED_RECT		; d668  cd 70 bf	Mp?
	LD	HL,XE31B	; d66b  21 1b e3	!.c
	CALL	STRING_RENDERER		; d66e  cd 26 bc	M&<
XD671:	LD	HL,XE1E8	; d671  21 e8 e1	!ha
	LD	B,4		; d674  06 04		..
	LD	IX,XBCA9	; d676  dd 21 a9 bc	]!)<
XD67A:	PUSH	BC		; d67a  c5		E
	LD	A,6		; d67b  3e 06		>.
	SUB	B		; d67d  90		.
	LD	(IX+1),A	; d67e  dd 77 01	]w.
	LD	(IX+0),68H	; d681  dd 36 00 68	]6.h
	LD	A,(HL)		; d685  7e		~
	INC	HL		; d686  23		#
	PUSH	HL		; d687  e5		e
	LD	HL,XE1EE	; d688  21 ee e1	!na
	CALL	XBB3B		; d68b  cd 3b bb	M;;
	CALL	STRING_RENDERER		; d68e  cd 26 bc	M&<
	POP	HL		; d691  e1		a
	POP	BC		; d692  c1		A
	DJNZ	XD67A		; d693  10 e5		.e
	LD	HL,XE468	; d695  21 68 e4	!hd
	CALL	XBF18		; d698  cd 18 bf	M.?
XD69B:	CALL	XBF3A		; d69b  cd 3a bf	M:?
	JR	NC,XD69B	; d69e  30 fb		0{
	CALL	XBF61		; d6a0  cd 61 bf	Ma?
	LD	A,(XBDF6)	; d6a3  3a f6 bd	:v=
	CP	8		; d6a6  fe 08		~.
	JR	NC,XD6BF	; d6a8  30 15		0.
	SRL	A		; d6aa  cb 3f		K?
	LD	E,A		; d6ac  5f		_
	CCF			; d6ad  3f		?
	SBC	A,A		; d6ae  9f		.
	ADD	A,A		; d6af  87		.
	INC	A		; d6b0  3c		<
	LD	D,0		; d6b1  16 00		..
	LD	HL,XE1E8	; d6b3  21 e8 e1	!ha
	ADD	HL,DE		; d6b6  19		.
	ADD	A,(HL)		; d6b7  86		.
	CP	7		; d6b8  fe 07		~.
	JR	NC,XD671	; d6ba  30 b5		05
	LD	(HL),A		; d6bc  77		w
	JR	XD671		; d6bd  18 b2		.2
;
XD6BF:	CALL	RESTORE_RECT		; d6bf  cd 3e c0	M>@
	LD	C,38H		; d6c2  0e 38		.8
	CALL	XD7BB		; d6c4  cd bb d7	M;W
	RET			; d6c7  c9		I
;
	LD	BC,X0011	; d6c8  01 11 00	...
	LD	DE,X0A09	; d6cb  11 09 0a	...
	LD	A,30H		; d6ce  3e 30		>0
	CALL	DRAW_BORDERED_RECT		; d6d0  cd 70 bf	Mp?
	LD	HL,XE367	; d6d3  21 67 e3	!gc
	CALL	STRING_RENDERER		; d6d6  cd 26 bc	M&<
XD6D9:	LD	B,4		; d6d9  06 04		..
	LD	IX,XBCA9	; d6db  dd 21 a9 bc	]!)<
XD6DF:	LD	A,4		; d6df  3e 04		>.
	SUB	B		; d6e1  90		.
	LD	C,A		; d6e2  4f		O
	LD	A,9CH		; d6e3  3e 9c		>.
	BIT	0,C		; d6e5  cb 41		KA
	JR	Z,XD6EB		; d6e7  28 02		(.
	ADD	A,20H		; d6e9  c6 20		F 
XD6EB:	LD	(IX+0),A	; d6eb  dd 77 00	]w.
	LD	A,C		; d6ee  79		y
	SRL	A		; d6ef  cb 3f		K?
	ADD	A,3		; d6f1  c6 03		F.
	LD	(IX+1),A	; d6f3  dd 77 01	]w.
	LD	A,(XE1E7)	; d6f6  3a e7 e1	:ga
	CP	C		; d6f9  b9		9
	LD	A,9EH		; d6fa  3e 9e		>.
	JR	NZ,XD6FF	; d6fc  20 01		 .
	INC	A		; d6fe  3c		<
XD6FF:	CALL	XBCB5		; d6ff  cd b5 bc	M5<
	DJNZ	XD6DF		; d702  10 db		.[
	CALL	XD756		; d704  cd 56 d7	MVW
	LD	HL,XE484	; d707  21 84 e4	!.d
XD70A:	CALL	XBF18		; d70a  cd 18 bf	M.?
XD70D:	CALL	XBF3A		; d70d  cd 3a bf	M:?
	JR	NC,XD70D	; d710  30 fb		0{
	CALL	XBF61		; d712  cd 61 bf	Ma?
	LD	A,(XBDF6)	; d715  3a f6 bd	:v=
	CP	4		; d718  fe 04		~.
	JR	NC,XD721	; d71a  30 05		0.
	LD	(XE1E7),A	; d71c  32 e7 e1	2ga
	JR	XD6D9		; d71f  18 b8		.8
;
XD721:	CALL	RESTORE_RECT		; d721  cd 3e c0	M>@
	LD	A,(XBDF6)	; d724  3a f6 bd	:v=
	CP	4		; d727  fe 04		~.
	JR	NZ,XD740	; d729  20 15		 .
	LD	HL,XDB31	; d72b  21 31 db	!1[
	LD	A,(XE1E7)	; d72e  3a e7 e1	:ga
	LD	(HL),A		; d731  77		w
	LD	DE,XDB32	; d732  11 32 db	.2[
	LD	BC,X0351	; d735  01 51 03	.Q.
	LDIR			; d738  ed b0		m0
	LD	C,38H		; d73a  0e 38		.8
	CALL	XD7BB		; d73c  cd bb d7	M;W
	RET			; d73f  c9		I
;
XD740:	CP	5		; d740  fe 05		~.
	JR	NZ,XD755	; d742  20 11		 .
	LD	HL,XD7DF	; d744  21 df d7	!_W
	LD	DE,XDB31	; d747  11 31 db	.1[
	LD	BC,X0352	; d74a  01 52 03	.R.
	LDIR			; d74d  ed b0		m0
	LD	C,38H		; d74f  0e 38		.8
	CALL	XD7BB		; d751  cd bb d7	M;W
	RET			; d754  c9		I
;
XD755:	RET			; d755  c9		I
;
XD756:	LD	IX,XBCA9	; d756  dd 21 a9 bc	]!)<
	LD	(IX+0),0F8H	; d75a  dd 36 00 f8	]6.x
	LD	(IX+1),0	; d75e  dd 36 01 00	]6..
	LD	A,(XE1E7)	; d762  3a e7 e1	:ga
	LD	E,A		; d765  5f		_
	LD	D,0		; d766  16 00		..
	LD	HL,XE1E8	; d768  21 e8 e1	!ha
	ADD	HL,DE		; d76b  19		.
	LD	A,(IX+2)	; d76c  dd 7e 02	]~.
	PUSH	AF		; d76f  f5		u
	LD	A,(HL)		; d770  7e		~
	SET	7,A		; d771  cb ff		K.
	LD	(IX+2),A	; d773  dd 77 02	]w.
	LD	A,7EH		; d776  3e 7e		>~
	CALL	XBCB5		; d778  cd b5 bc	M5<
	POP	AF		; d77b  f1		q
	LD	(IX+2),A	; d77c  dd 77 02	]w.
	RET			; d77f  c9		I
;
XD780:	LD	HL,XDB31	; d780  21 31 db	!1[
	LD	DE,XDE83	; d783  11 83 de	..^
	LD	BC,X0352	; d786  01 52 03	.R.
	LDIR			; d789  ed b0		m0
	LD	HL,XDB54	; d78b  21 54 db	!T[
	LD	IX,XDEA6	; d78e  dd 21 a6 de	]!&^
	LD	C,17H		; d792  0e 17		..
XD794:	LD	B,20H		; d794  06 20		. 
XD796:	LD	A,(IX+0DEH)	; d796  dd 7e de	]~^
	ADD	A,(IX+0FFH)	; d799  dd 86 ff	]..
	ADD	A,(IX+1)	; d79c  dd 86 01	]..
	ADD	A,(IX+22H)	; d79f  dd 86 22	]."
	LD	DE,XE1D5	; d7a2  11 d5 e1	.Ua
	ADD	A,E		; d7a5  83		.
	LD	E,A		; d7a6  5f		_
	ADC	A,D		; d7a7  8a		.
	SUB	E		; d7a8  93		.
	LD	D,A		; d7a9  57		W
	LD	A,(DE)		; d7aa  1a		.
	LD	(HL),A		; d7ab  77		w
	INC	HL		; d7ac  23		#
	INC	IX		; d7ad  dd 23		]#
	DJNZ	XD796		; d7af  10 e5		.e
	INC	HL		; d7b1  23		#
	INC	HL		; d7b2  23		#
	INC	IX		; d7b3  dd 23		]#
	INC	IX		; d7b5  dd 23		]#
	DEC	C		; d7b7  0d		.
	JR	NZ,XD794	; d7b8  20 da		 Z
	RET			; d7ba  c9		I
;
XD7BB:	LD	HL,XDB54	; d7bb  21 54 db	!T[
	LD	DE,X5820	; d7be  11 20 58	. X
	LD	B,17H		; d7c1  06 17		..
	EXX			; d7c3  d9		Y
	LD	DE,XE1E8	; d7c4  11 e8 e1	.ha
	EXX			; d7c7  d9		Y
XD7C8:	PUSH	BC		; d7c8  c5		E
	LD	B,20H		; d7c9  06 20		. 
XD7CB:	LD	A,(HL)		; d7cb  7e		~
	EXX			; d7cc  d9		Y
	LD	L,A		; d7cd  6f		o
	LD	H,0		; d7ce  26 00		&.
	ADD	HL,DE		; d7d0  19		.
	LD	A,(HL)		; d7d1  7e		~
	EXX			; d7d2  d9		Y
	OR	C		; d7d3  b1		1
	LD	(DE),A		; d7d4  12		.
	INC	HL		; d7d5  23		#
	INC	DE		; d7d6  13		.
	DJNZ	XD7CB		; d7d7  10 f2		.r
	INC	HL		; d7d9  23		#
	INC	HL		; d7da  23		#
	POP	BC		; d7db  c1		A
	DJNZ	XD7C8		; d7dc  10 ea		.j
	RET			; d7de  c9		I
;
XD7DF:	NOP			; d7df  00		.
;
	ORG	0DB31H
;
XDB31:	NOP			; db31  00		.
XDB32:	NOP			; db32  00		.
;
	ORG	0DB54H
;
XDB54:	NOP			; db54  00		.
;
	ORG	0DE83H
;
XDE83:	NOP			; de83  00		.
;
	ORG	0E01FH
;
XE01F:	NOP			; e01f  00		.
;
	ORG	0E1D5H
;
XE1D5:	NOP			; e1d5  00		.
;
	DB	1,0,2,2,0				; e1d6 .....
;
	ORG	0E1DDH
;
	DB	2,1,2,1,3				; e1dd .....
;
	ORG	0E1E6H
;
XE1E6:	NOP			; e1e6  00		.
;
XE1E7:	DB	1					; e1e7 .
XE1E8:	DB	0,1,2					; e1e8 ...
XE1EB:	DB	3					; e1eb .
;
XE1EC:	NOP			; e1ec  00		.
;
	ORG	0E1EEH
;
XE1EE:	DB	42H,6CH					; e1ee Bl
;
	LD	H,C		; e1f0  61		a
	LD	H,E		; e1f1  63		c
	LD	L,E		; e1f2  6b		k
	DEC	E		; e1f3  1d		.
	LD	A,(HL)		; e1f4  7e		~
	LD	A,(HL)		; e1f5  7e		~
	LD	A,(HL)		; e1f6  7e		~
	NOP			; e1f7  00		.
	LD	B,D		; e1f8  42		B
	LD	L,H		; e1f9  6c		l
	LD	(HL),L		; e1fa  75		u
	LD	H,L		; e1fb  65		e
	DEC	E		; e1fc  1d		.
	LD	A,(HL)		; e1fd  7e		~
	LD	A,(HL)		; e1fe  7e		~
	LD	A,(HL)		; e1ff  7e		~
	NOP			; e200  00		.
	LD	D,D		; e201  52		R
	LD	H,L		; e202  65		e
	LD	H,H		; e203  64		d
	DEC	E		; e204  1d		.
	LD	A,(HL)		; e205  7e		~
	LD	A,(HL)		; e206  7e		~
	LD	A,(HL)		; e207  7e		~
	LD	A,(HL)		; e208  7e		~
;
	DB	0					; e209 .
	DB	'Magenta'				; e20a
	DB	0,47H,72H,65H,65H,6EH,1DH,7EH		; e211 .Green.~
	DB	7EH,0,43H,79H,61H,6EH,1DH,7EH		; e219 ~.Cyan.~
	DB	7EH,7EH,0				; e221 ~~.
	DB	'Yellow'				; e224
	DB	1DH,7EH,0,57H,68H,69H,74H,65H		; e22a .~.White
	DB	1DH,7EH,7EH,0				; e232 .~~.
XE236:	DB	1FH,0,0,1EH				; e236 ....
	DB	'0~Run'					; e23a
	DB	1DH					; e23f .
	DB	'~~Rule'				; e240
	DB	1DH					; e246 .
	DB	'~~Col.Map'				; e247
	DB	1DH					; e250 .
	DB	'~~Edit'				; e251
	DB	1DH					; e257 .
	DB	'~~~Exit'				; e258
	DB	1DH,7EH,7EH,7EH,0			; e25f .~~~.
XE264:	DB	1FH,28H,0,1EH,0B0H,7EH,52H,75H		; e264 .(..0~Ru
	DB	6CH,65H,1DH,1CH,4,7EH,1EH,30H		; e26c le...~.0
	DB	1FH,34H,2,80H,1FH,42H,2,5DH		; e274 .4...B.]
	DB	1FH					; e27c .
	DW	X025C		; e27d   5c 02      \.
;
	DB	60H,1FH,34H,3,81H,1FH,42H,3		; e27f `.4...B.
	DB	5DH,1FH					; e287 ].
	DW	X035C		; e289   5c 03      \.
;
	DB	60H,1FH,34H,4,82H,1FH,42H,4		; e28b `.4...B.
	DB	5DH,1FH					; e293 ].
	DW	X045C		; e295   5c 04      \.
;
	DB	60H,1FH,34H,5,83H,1FH,42H,5		; e297 `.4...B.
	DB	5DH,1FH					; e29f ].
	DW	X055C		; e2a1   5c 05      \.
;
	DB	60H,1FH,34H,6,84H,1FH,42H,6		; e2a3 `.4...B.
	DB	5DH,1FH,5CH,6,60H,1FH,34H,7		; e2ab ].\.`.4.
	DB	85H,1FH,42H,7,5DH,1FH,5CH,7		; e2b3 ..B.].\.
	DB	60H,1FH,34H,8,86H,1FH,42H,8		; e2bb `.4...B.
	DB	5DH,1FH,5CH,8,60H,1FH,34H,9		; e2c3 ].\.`.4.
	DB	87H,1FH					; e2cb ..
;
	LD	B,D		; e2cd  42		B
	ADD	HL,BC		; e2ce  09		.
	LD	E,L		; e2cf  5d		]
	RRA			; e2d0  1f		.
	LD	E,H		; e2d1  5c		\
	ADD	HL,BC		; e2d2  09		.
	LD	H,B		; e2d3  60		`
	RRA			; e2d4  1f		.
	INC	(HL)		; e2d5  34		4
	LD	A,(BC)		; e2d6  0a		.
	ADC	A,B		; e2d7  88		.
	RRA			; e2d8  1f		.
	LD	B,D		; e2d9  42		B
	LD	A,(BC)		; e2da  0a		.
	LD	E,L		; e2db  5d		]
	RRA			; e2dc  1f		.
	LD	E,H		; e2dd  5c		\
	LD	A,(BC)		; e2de  0a		.
	LD	H,B		; e2df  60		`
	RRA			; e2e0  1f		.
	INC	(HL)		; e2e1  34		4
	DEC	BC		; e2e2  0b		.
	ADC	A,C		; e2e3  89		.
	RRA			; e2e4  1f		.
	LD	B,D		; e2e5  42		B
	DEC	BC		; e2e6  0b		.
	LD	E,L		; e2e7  5d		]
	RRA			; e2e8  1f		.
	LD	E,H		; e2e9  5c		\
	DEC	BC		; e2ea  0b		.
	LD	H,B		; e2eb  60		`
	RRA			; e2ec  1f		.
	LD	HL,(X810C)	; e2ed  2a 0c 81	*..
	ADD	A,B		; e2f0  80		.
	RRA			; e2f1  1f		.
	LD	B,D		; e2f2  42		B
	INC	C		; e2f3  0c		.
	LD	E,L		; e2f4  5d		]
	RRA			; e2f5  1f		.
	LD	E,H		; e2f6  5c		\
XE2F7:	INC	C		; e2f7  0c		.
	LD	H,B		; e2f8  60		`
	RRA			; e2f9  1f		.
	LD	HL,(X810D)	; e2fa  2a 0d 81	*..
	ADD	A,C		; e2fd  81		.
	RRA			; e2fe  1f		.
	LD	B,D		; e2ff  42		B
	DEC	C		; e300  0d		.
	LD	E,L		; e301  5d		]
	RRA			; e302  1f		.
	LD	E,H		; e303  5c		\
	DEC	C		; e304  0d		.
	LD	H,B		; e305  60		`
	RRA			; e306  1f		.
	LD	HL,(X810E)	; e307  2a 0e 81	*..
	ADD	A,D		; e30a  82		.
	RRA			; e30b  1f		.
	LD	B,D		; e30c  42		B
	LD	C,5DH		; e30d  0e 5d		.]
	RRA			; e30f  1f		.
	LD	E,H		; e310  5c		\
	LD	C,60H		; e311  0e 60		.`
	RRA			; e313  1f		.
	LD	HL,(X4510)	; e314  2a 10 45	*.E
	LD	A,B		; e317  78		x
	LD	L,C		; e318  69		i
	LD	(HL),H		; e319  74		t
	NOP			; e31a  00		.
XE31B:	LD	E,0B0H		; e31b  1e b0		.0
	RRA			; e31d  1f		.
	LD	C,B		; e31e  48		H
	NOP			; e31f  00		.
;
	DB	'~~Col.Map'				; e320
	DB	1DH,1CH,5,7EH,1EH,30H,1FH,4CH		; e329 ...~.0.L
	DB	2,80H,1FH				; e331 ...
	DW	X025C		; e334   5c 02      \.
;
	DB	5DH,1FH,0A4H,2,60H,1FH,4CH,3		; e336 ].$.`.L.
	DB	81H,1FH					; e33e ..
	DW	X035C		; e340   5c 03      \.
;
	DB	5DH,1FH,0A4H,3,60H,1FH,4CH,4		; e342 ].$.`.L.
	DB	82H,1FH					; e34a ..
	DW	X045C		; e34c   5c 04      \.
;
	DB	5DH,1FH,0A4H,4,60H,1FH,4CH,5		; e34e ].$.`.L.
	DB	83H,1FH					; e356 ..
	DW	X055C		; e358   5c 05      \.
;
	DB	5DH,1FH,0A4H,5,60H,1FH,4CH,7		; e35a ].$.`.L.
	DB	45H,78H,69H,74H,0			; e362 Exit.
XE367:	DB	1EH,0B0H,1FH,88H,0			; e367 .0...
	DB	'~~Edit'				; e36c
	DB	1DH,1CH,4,7EH,1EH,30H,1FH,8CH		; e372 ...~.0..
	DB	2					; e37a .
	DB	'Colour No'				; e37b
	DB	1FH,8CH,3,80H,7EH,9EH,7EH,81H		; e384 ....~.~.
	DB	7EH,9EH,7EH,1FH,8CH,4,82H,7EH		; e38c ~.~....~
	DB	9EH,7EH,83H,7EH,9EH,1FH,8CH,6		; e394 .~.~....
	DB	'Clear'					; e39c
	DB	1FH,8CH,7				; e3a1 ...
	DB	'Restore'				; e3a4
	DB	1FH,8CH,8,45H,78H			; e3ab ...Ex
;
	LD	L,C		; e3b0  69		i
	LD	(HL),H		; e3b1  74		t
	NOP			; e3b2  00		.
XE3B3:	LD	E,0B0H		; e3b3  1e b0		.0
	RRA			; e3b5  1f		.
	NOP			; e3b6  00		.
	NOP			; e3b7  00		.
	LD	A,(HL)		; e3b8  7e		~
	LD	D,D		; e3b9  52		R
	LD	(HL),L		; e3ba  75		u
	LD	L,(HL)		; e3bb  6e		n
	DEC	E		; e3bc  1d		.
	INC	E		; e3bd  1c		.
	INC	B		; e3be  04		.
	LD	A,(HL)		; e3bf  7e		~
	LD	E,30H		; e3c0  1e 30		.0
	RRA			; e3c2  1f		.
	INC	B		; e3c3  04		.
;
	DB	2					; e3c4 .
	DB	'Speed'					; e3c5
	DB	1FH,4,3,46H,61H,73H,74H,1FH		; e3ca ...Fast.
	DB	4,4,4DH,65H,64H,1FH,4,5			; e3d2 ..Med...
	DB	53H,6CH,6FH,77H,1FH,4,6			; e3da Slow...
	DB	'S.Step'				; e3e1
	DB	1FH,4,8,47H,6FH,21H,1FH,4		; e3e7 ...Go!..
	DB	0AH					; e3ef .
	DB	'Cancel'				; e3f0
	DB	0					; e3f6 .
XE3F7:	DB	1EH					; e3f7 .
;
	DEC	B		; e3f8  05		.
	RRA			; e3f9  1f		.
	NOP			; e3fa  00		.
	NOP			; e3fb  00		.
	INC	E		; e3fc  1c		.
	JR	NZ,XE47D	; e3fd  20 7e		 ~
	NOP			; e3ff  00		.
XE400:	LD	E,5		; e400  1e 05		..
	RRA			; e402  1f		.
	RET	C		; e403  d8		X
	NOP			; e404  00		.
;
	ORG	0E406H
;
XE406:	NOP			; e406  00		.
;
	ORG	0E408H
;
	DB	5,5,0,5,0AH,0,8,12H			; e408 ........
	DB	0,6,18H,0,6,0FFH			; e410 ......
XE416:	DB	8,2,2,0BH,2,2,8,3			; e416 ........
	DB	2,0BH,3,2,8,4,2,0BH			; e41e ........
	DB	4,2,8,5,2,0BH,5,2			; e426 ........
	DB	8,6,2,0BH,6,2,8,7			; e42e ........
	DB	2,0BH,7,2,8,8,2,0BH			; e436 ........
;
	EX	AF,AF'		; e43e  08		.
	LD	(BC),A		; e43f  02		.
	EX	AF,AF'		; e440  08		.
	ADD	HL,BC		; e441  09		.
	LD	(BC),A		; e442  02		.
	DEC	BC		; e443  0b		.
	ADD	HL,BC		; e444  09		.
	LD	(BC),A		; e445  02		.
	EX	AF,AF'		; e446  08		.
	LD	A,(BC)		; e447  0a		.
	LD	(BC),A		; e448  02		.
	DEC	BC		; e449  0b		.
	LD	A,(BC)		; e44a  0a		.
	LD	(BC),A		; e44b  02		.
	EX	AF,AF'		; e44c  08		.
	DEC	BC		; e44d  0b		.
	LD	(BC),A		; e44e  02		.
	DEC	BC		; e44f  0b		.
	DEC	BC		; e450  0b		.
	LD	(BC),A		; e451  02		.
	EX	AF,AF'		; e452  08		.
	INC	C		; e453  0c		.
	LD	(BC),A		; e454  02		.
	DEC	BC		; e455  0b		.
	INC	C		; e456  0c		.
	LD	(BC),A		; e457  02		.
	EX	AF,AF'		; e458  08		.
	DEC	C		; e459  0d		.
	LD	(BC),A		; e45a  02		.
	DEC	BC		; e45b  0b		.
	DEC	C		; e45c  0d		.
	LD	(BC),A		; e45d  02		.
	EX	AF,AF'		; e45e  08		.
	LD	C,2		; e45f  0e 02		..
	DEC	BC		; e461  0b		.
	LD	C,2		; e462  0e 02		..
	DEC	B		; e464  05		.
	DJNZ	XE46F		; e465  10 08		..
	RST	38H		; e467  ff		.
XE468:	DEC	BC		; e468  0b		.
	LD	(BC),A		; e469  02		.
	LD	(BC),A		; e46a  02		.
	INC	D		; e46b  14		.
	LD	(BC),A		; e46c  02		.
	LD	(BC),A		; e46d  02		.
	DEC	BC		; e46e  0b		.
XE46F:	INC	BC		; e46f  03		.
	LD	(BC),A		; e470  02		.
	INC	D		; e471  14		.
	INC	BC		; e472  03		.
	LD	(BC),A		; e473  02		.
	DEC	BC		; e474  0b		.
	INC	B		; e475  04		.
	LD	(BC),A		; e476  02		.
	INC	D		; e477  14		.
	INC	B		; e478  04		.
	LD	(BC),A		; e479  02		.
	DEC	BC		; e47a  0b		.
	DEC	B		; e47b  05		.
	LD	(BC),A		; e47c  02		.
XE47D:	INC	D		; e47d  14		.
	DEC	B		; e47e  05		.
	LD	(BC),A		; e47f  02		.
	ADD	HL,BC		; e480  09		.
	RLCA			; e481  07		.
	DEC	C		; e482  0d		.
	RST	38H		; e483  ff		.
XE484:	INC	DE		; e484  13		.
	INC	BC		; e485  03		.
	LD	(BC),A		; e486  02		.
	RLA			; e487  17		.
	INC	BC		; e488  03		.
	LD	(BC),A		; e489  02		.
	INC	DE		; e48a  13		.
	INC	B		; e48b  04		.
	LD	(BC),A		; e48c  02		.
	RLA			; e48d  17		.
	INC	B		; e48e  04		.
	LD	(BC),A		; e48f  02		.
	LD	DE,X0906	; e490  11 06 09	...
	LD	DE,X0907	; e493  11 07 09	...
	LD	DE,X0908	; e496  11 08 09	...
	RST	38H		; e499  ff		.
XE49A:	NOP			; e49a  00		.
	INC	BC		; e49b  03		.
	EX	AF,AF'		; e49c  08		.
	NOP			; e49d  00		.
	INC	B		; e49e  04		.
	EX	AF,AF'		; e49f  08		.
	NOP			; e4a0  00		.
	DEC	B		; e4a1  05		.
	EX	AF,AF'		; e4a2  08		.
	NOP			; e4a3  00		.
	LD	B,8		; e4a4  06 08		..
	NOP			; e4a6  00		.
	EX	AF,AF'		; e4a7  08		.
	EX	AF,AF'		; e4a8  08		.
	NOP			; e4a9  00		.
	LD	A,(BC)		; e4aa  0a		.
	EX	AF,AF'		; e4ab  08		.
	RST	38H		; e4ac  ff		.
	LD	A,(HL)		; e4ad  7e		~
;
	ORG	0E4B4H
;
	DB	7EH					; e4b4 ~
XE4B5:	DB	1EH,70H,1FH,3FH,6			; e4b5 .p.?.
	DB	'Cellular 2D Automat'			; e4ba
Xe4cd:	DB	'on'					; e4cd
	DB	1FH					; e4cf .
	DW	X085B		; e4d0   5b 08      [.
;
	DB	'A rule based'				; e4d2
	DB	1FH,46H,9				; e4de .F.
	DB	'Pattern Generator'			; e4e1
	DB	1FH,40H,0CH				; e4f2 .@.
	DB	'By Pete Cooke Dec 87'			; e4f5
	DB	1FH,5CH,10H				; e509 .\.
	DB	'Information'				; e50c
	DB	1FH,4CH,12H				; e517 .L.
	DB	'Start Automaton'			; e51a
	DB	0,4,10H,18H,4,12H,18H			; e529 .......
	DW	X1EFF		; e530   ff 1e      ..
;
	DB	46H,1FH,3FH,2				; e532 F.?.
	DB	'Cellular 2D Automaton'			; e536
	DB	1FH					; e54b .
	DW	X055C		; e54c   5c 05      \.
;
	DB	'Information'				; e54e
	DB	1EH,6,1FH,8,8				; e559 .....
	DB	'This program is a variation on J'	; e55e
	DB	'ohn'					; e57e
;
	RRA			; e581  1f		.
	NOP			; e582  00		.
	ADD	HL,BC		; e583  09		.
;
	DB	'Conway'				; e584
	DB	27H					; e58a '
	DB	's Life. The screen is divided in'	; e58b
	DB	'to'					; e5ab
	DB	1FH,0,0AH				; e5ad ...
	DB	'a grid of CELLS and each cell ca'	; e5b0
	DB	'n have'				; e5d0
	DB	1FH,0,0BH				; e5d6 ...
	DB	'one of 4 colours. '			; e5d9
Xe5eb:	DB	'To calculate the colour'		; e5eb
;
	RRA			; e602  1f		.
	NOP			; e603  00		.
	INC	C		; e604  0c		.
;
	DB	'value of a cell in the next gene'	; e605
	DB	'ration the'				; e625
	DB	1FH,0,0DH				; e62f ...
	DB	'computer adds the value of the c'	; e632
	DB	'ells'					; e652
	DB	1FH,0,0EH				; e656 ...
	DB	'left, right, above and below it.'	; e659'
	DB	1FH,0,0FH				; e679 ...
	DB	'The corresponding entry in a tab'	; e67c
	DB	'le,'					; e69c
	DB	1FH,0,10H				; e69f ...
	DB	'known as the RULE table, then gi'	; e6a2
	DB	'ves'					; e6c2
	DB	1FH,0,11H				; e6c5 ...
	DB	'the new col'				; e6c8
Xe6d3:	DB	'our.'					; e6d3
	DB	1EH,46H,1FH,60H,16H			; e6d7 .F.`.
	DB	'Press Fire'				; e6dc
	DB	0					; e6e6 .
	DB	'Program Copyright Pete Cooke 198'	; e6e7
	DB	'7.Coded for Firebird Software De'	; e707
	DB	'c 87'					; e727
	DB	0					; e72b .
;
	ORG	0E87FH
;
XE87F:	NOP			; e87f  00		.
;
	ORG	0E8B7H
;
XE8B7:	NOP			; e8b7  00		.
;
	ORG	0EA7FH
;
XEA7F:	NOP			; ea7f  00		.
;
	ORG	0EABFH
;
XEABF:	NOP			; eabf  00		.
;
	ORG	0EAFFH
;
XEAFF:	NOP			; eaff  00		.
;
	ORG	0EB7FH
;
XEB7F:	NOP			; eb7f  00		.
;
	ORG	0ECCBH
;
XECCB:	NOP			; eccb  00		.
;
	ORG	0EDC8H
;
	NOP			; edc8  00		.
	NOP			; edc9  00		.
	NOP			; edca  00		.
	NOP			; edcb  00		.
	NOP			; edcc  00		.
	NOP			; edcd  00		.
	NOP			; edce  00		.
	NOP			; edcf  00		.
	NOP			; edd0  00		.
	NOP			; edd1  00		.
	NOP			; edd2  00		.
	NOP			; edd3  00		.
	NOP			; edd4  00		.
	NOP			; edd5  00		.
	NOP			; edd6  00		.
	NOP			; edd7  00		.
	NOP			; edd8  00		.
	NOP			; edd9  00		.
	NOP			; edda  00		.
	NOP			; eddb  00		.
	NOP			; eddc  00		.
	NOP			; eddd  00		.
	NOP			; edde  00		.
	NOP			; eddf  00		.
	NOP			; ede0  00		.
	NOP			; ede1  00		.
	NOP			; ede2  00		.
	NOP			; ede3  00		.
	NOP			; ede4  00		.
	NOP			; ede5  00		.
	NOP			; ede6  00		.
	NOP			; ede7  00		.
	NOP			; ede8  00		.
	NOP			; ede9  00		.
	NOP			; edea  00		.
	NOP			; edeb  00		.
	NOP			; edec  00		.
	NOP			; eded  00		.
	NOP			; edee  00		.
	NOP			; edef  00		.
	NOP			; edf0  00		.
	NOP			; edf1  00		.
	NOP			; edf2  00		.
	NOP			; edf3  00		.
	NOP			; edf4  00		.
	NOP			; edf5  00		.
	NOP			; edf6  00		.
	NOP			; edf7  00		.
	NOP			; edf8  00		.
	NOP			; edf9  00		.
	NOP			; edfa  00		.
	NOP			; edfb  00		.
	NOP			; edfc  00		.
	NOP			; edfd  00		.
XEDFE:	NOP			; edfe  00		.
XEDFF:	NOP			; edff  00		.
	NOP			; ee00  00		.
	NOP			; ee01  00		.
	NOP			; ee02  00		.
	NOP			; ee03  00		.
	NOP			; ee04  00		.
	NOP			; ee05  00		.
	NOP			; ee06  00		.
	NOP			; ee07  00		.
	NOP			; ee08  00		.
	NOP			; ee09  00		.
	NOP			; ee0a  00		.
	NOP			; ee0b  00		.
	NOP			; ee0c  00		.
	NOP			; ee0d  00		.
	NOP			; ee0e  00		.
	NOP			; ee0f  00		.
	NOP			; ee10  00		.
	NOP			; ee11  00		.
	NOP			; ee12  00		.
	NOP			; ee13  00		.
	NOP			; ee14  00		.
	NOP			; ee15  00		.
	NOP			; ee16  00		.
	NOP			; ee17  00		.
	NOP			; ee18  00		.
	NOP			; ee19  00		.
	NOP			; ee1a  00		.
	NOP			; ee1b  00		.
	NOP			; ee1c  00		.
	NOP			; ee1d  00		.
	NOP			; ee1e  00		.
	NOP			; ee1f  00		.
	NOP			; ee20  00		.
	NOP			; ee21  00		.
	NOP			; ee22  00		.
	NOP			; ee23  00		.
	NOP			; ee24  00		.
	NOP			; ee25  00		.
	NOP			; ee26  00		.
	NOP			; ee27  00		.
	NOP			; ee28  00		.
	NOP			; ee29  00		.
	NOP			; ee2a  00		.
	NOP			; ee2b  00		.
	NOP			; ee2c  00		.
	NOP			; ee2d  00		.
	NOP			; ee2e  00		.
	NOP			; ee2f  00		.
	NOP			; ee30  00		.
	NOP			; ee31  00		.
	NOP			; ee32  00		.
	NOP			; ee33  00		.
	NOP			; ee34  00		.
	NOP			; ee35  00		.
	NOP			; ee36  00		.
	NOP			; ee37  00		.
	NOP			; ee38  00		.
	NOP			; ee39  00		.
	NOP			; ee3a  00		.
	NOP			; ee3b  00		.
	NOP			; ee3c  00		.
	NOP			; ee3d  00		.
	NOP			; ee3e  00		.
	NOP			; ee3f  00		.
	NOP			; ee40  00		.
	NOP			; ee41  00		.
	NOP			; ee42  00		.
	NOP			; ee43  00		.
	NOP			; ee44  00		.
	NOP			; ee45  00		.
	NOP			; ee46  00		.
	NOP			; ee47  00		.
	NOP			; ee48  00		.
	NOP			; ee49  00		.
	NOP			; ee4a  00		.
	NOP			; ee4b  00		.
	NOP			; ee4c  00		.
	NOP			; ee4d  00		.
	NOP			; ee4e  00		.
	NOP			; ee4f  00		.
	NOP			; ee50  00		.
	NOP			; ee51  00		.
	NOP			; ee52  00		.
	NOP			; ee53  00		.
	NOP			; ee54  00		.
	NOP			; ee55  00		.
	NOP			; ee56  00		.
	NOP			; ee57  00		.
	NOP			; ee58  00		.
	NOP			; ee59  00		.
	NOP			; ee5a  00		.
	NOP			; ee5b  00		.
	NOP			; ee5c  00		.
	NOP			; ee5d  00		.
	NOP			; ee5e  00		.
	NOP			; ee5f  00		.
	NOP			; ee60  00		.
	NOP			; ee61  00		.
	NOP			; ee62  00		.
	NOP			; ee63  00		.
	NOP			; ee64  00		.
	NOP			; ee65  00		.
	NOP			; ee66  00		.
	NOP			; ee67  00		.
	NOP			; ee68  00		.
	NOP			; ee69  00		.
	NOP			; ee6a  00		.
	NOP			; ee6b  00		.
	NOP			; ee6c  00		.
	NOP			; ee6d  00		.
	NOP			; ee6e  00		.
	NOP			; ee6f  00		.
	NOP			; ee70  00		.
	NOP			; ee71  00		.
	NOP			; ee72  00		.
	NOP			; ee73  00		.
	NOP			; ee74  00		.
	NOP			; ee75  00		.
	NOP			; ee76  00		.
	NOP			; ee77  00		.
	NOP			; ee78  00		.
	NOP			; ee79  00		.
	NOP			; ee7a  00		.
	NOP			; ee7b  00		.
	NOP			; ee7c  00		.
	NOP			; ee7d  00		.
	NOP			; ee7e  00		.
	NOP			; ee7f  00		.
	NOP			; ee80  00		.
	NOP			; ee81  00		.
	NOP			; ee82  00		.
	NOP			; ee83  00		.
	NOP			; ee84  00		.
	NOP			; ee85  00		.
	NOP			; ee86  00		.
	NOP			; ee87  00		.
	NOP			; ee88  00		.
	NOP			; ee89  00		.
	NOP			; ee8a  00		.
	NOP			; ee8b  00		.
	NOP			; ee8c  00		.
	NOP			; ee8d  00		.
	NOP			; ee8e  00		.
	NOP			; ee8f  00		.
	NOP			; ee90  00		.
	NOP			; ee91  00		.
	NOP			; ee92  00		.
	NOP			; ee93  00		.
	NOP			; ee94  00		.
	NOP			; ee95  00		.
	NOP			; ee96  00		.
	NOP			; ee97  00		.
	NOP			; ee98  00		.
	NOP			; ee99  00		.
	NOP			; ee9a  00		.
	NOP			; ee9b  00		.
	NOP			; ee9c  00		.
	NOP			; ee9d  00		.
	NOP			; ee9e  00		.
	NOP			; ee9f  00		.
	NOP			; eea0  00		.
	NOP			; eea1  00		.
	NOP			; eea2  00		.
	NOP			; eea3  00		.
	NOP			; eea4  00		.
	NOP			; eea5  00		.
	NOP			; eea6  00		.
	NOP			; eea7  00		.
	NOP			; eea8  00		.
	NOP			; eea9  00		.
	NOP			; eeaa  00		.
	NOP			; eeab  00		.
	NOP			; eeac  00		.
	NOP			; eead  00		.
	NOP			; eeae  00		.
	NOP			; eeaf  00		.
	NOP			; eeb0  00		.
	NOP			; eeb1  00		.
	NOP			; eeb2  00		.
	NOP			; eeb3  00		.
	NOP			; eeb4  00		.
	NOP			; eeb5  00		.
	NOP			; eeb6  00		.
	NOP			; eeb7  00		.
	NOP			; eeb8  00		.
	NOP			; eeb9  00		.
	NOP			; eeba  00		.
	NOP			; eebb  00		.
	NOP			; eebc  00		.
	NOP			; eebd  00		.
	NOP			; eebe  00		.
	NOP			; eebf  00		.
	NOP			; eec0  00		.
	NOP			; eec1  00		.
	NOP			; eec2  00		.
	NOP			; eec3  00		.
	NOP			; eec4  00		.
	NOP			; eec5  00		.
	NOP			; eec6  00		.
	NOP			; eec7  00		.
	NOP			; eec8  00		.
	NOP			; eec9  00		.
	NOP			; eeca  00		.
	NOP			; eecb  00		.
	NOP			; eecc  00		.
	NOP			; eecd  00		.
	NOP			; eece  00		.
	NOP			; eecf  00		.
	NOP			; eed0  00		.
	NOP			; eed1  00		.
	NOP			; eed2  00		.
	NOP			; eed3  00		.
	NOP			; eed4  00		.
	NOP			; eed5  00		.
	NOP			; eed6  00		.
	NOP			; eed7  00		.
	NOP			; eed8  00		.
	NOP			; eed9  00		.
	NOP			; eeda  00		.
	NOP			; eedb  00		.
	NOP			; eedc  00		.
	NOP			; eedd  00		.
	NOP			; eede  00		.
	NOP			; eedf  00		.
	NOP			; eee0  00		.
	NOP			; eee1  00		.
	NOP			; eee2  00		.
	NOP			; eee3  00		.
	NOP			; eee4  00		.
	NOP			; eee5  00		.
	NOP			; eee6  00		.
	NOP			; eee7  00		.
	NOP			; eee8  00		.
	NOP			; eee9  00		.
	NOP			; eeea  00		.
	NOP			; eeeb  00		.
	NOP			; eeec  00		.
	NOP			; eeed  00		.
	NOP			; eeee  00		.
	NOP			; eeef  00		.
	NOP			; eef0  00		.
	NOP			; eef1  00		.
	NOP			; eef2  00		.
	NOP			; eef3  00		.
	NOP			; eef4  00		.
	NOP			; eef5  00		.
	NOP			; eef6  00		.
	NOP			; eef7  00		.
	NOP			; eef8  00		.
	NOP			; eef9  00		.
	NOP			; eefa  00		.
	NOP			; eefb  00		.
	NOP			; eefc  00		.
	NOP			; eefd  00		.
	NOP			; eefe  00		.
	NOP			; eeff  00		.
	NOP			; ef00  00		.
	NOP			; ef01  00		.
	NOP			; ef02  00		.
	NOP			; ef03  00		.
	NOP			; ef04  00		.
	NOP			; ef05  00		.
	NOP			; ef06  00		.
	NOP			; ef07  00		.
	NOP			; ef08  00		.
	NOP			; ef09  00		.
	NOP			; ef0a  00		.
	NOP			; ef0b  00		.
	NOP			; ef0c  00		.
	NOP			; ef0d  00		.
	NOP			; ef0e  00		.
	NOP			; ef0f  00		.
	NOP			; ef10  00		.
	NOP			; ef11  00		.
	NOP			; ef12  00		.
	NOP			; ef13  00		.
	NOP			; ef14  00		.
	NOP			; ef15  00		.
	NOP			; ef16  00		.
	NOP			; ef17  00		.
	NOP			; ef18  00		.
	NOP			; ef19  00		.
	NOP			; ef1a  00		.
	NOP			; ef1b  00		.
	NOP			; ef1c  00		.
	NOP			; ef1d  00		.
	NOP			; ef1e  00		.
	NOP			; ef1f  00		.
	NOP			; ef20  00		.
	NOP			; ef21  00		.
	NOP			; ef22  00		.
	NOP			; ef23  00		.
	NOP			; ef24  00		.
	NOP			; ef25  00		.
	NOP			; ef26  00		.
	NOP			; ef27  00		.
	NOP			; ef28  00		.
	NOP			; ef29  00		.
	NOP			; ef2a  00		.
	NOP			; ef2b  00		.
	NOP			; ef2c  00		.
	NOP			; ef2d  00		.
	NOP			; ef2e  00		.
	NOP			; ef2f  00		.
	NOP			; ef30  00		.
	NOP			; ef31  00		.
	NOP			; ef32  00		.
	NOP			; ef33  00		.
	NOP			; ef34  00		.
	NOP			; ef35  00		.
	NOP			; ef36  00		.
	NOP			; ef37  00		.
	NOP			; ef38  00		.
	NOP			; ef39  00		.
	NOP			; ef3a  00		.
	NOP			; ef3b  00		.
	NOP			; ef3c  00		.
	NOP			; ef3d  00		.
	NOP			; ef3e  00		.
	NOP			; ef3f  00		.
	NOP			; ef40  00		.
	NOP			; ef41  00		.
	NOP			; ef42  00		.
	NOP			; ef43  00		.
	NOP			; ef44  00		.
	NOP			; ef45  00		.
	NOP			; ef46  00		.
	NOP			; ef47  00		.
	NOP			; ef48  00		.
	NOP			; ef49  00		.
	NOP			; ef4a  00		.
	NOP			; ef4b  00		.
	NOP			; ef4c  00		.
	NOP			; ef4d  00		.
	NOP			; ef4e  00		.
	NOP			; ef4f  00		.
	NOP			; ef50  00		.
	NOP			; ef51  00		.
	NOP			; ef52  00		.
	NOP			; ef53  00		.
	NOP			; ef54  00		.
	NOP			; ef55  00		.
	NOP			; ef56  00		.
	NOP			; ef57  00		.
	NOP			; ef58  00		.
	NOP			; ef59  00		.
	NOP			; ef5a  00		.
	NOP			; ef5b  00		.
	NOP			; ef5c  00		.
	NOP			; ef5d  00		.
	NOP			; ef5e  00		.
	NOP			; ef5f  00		.
	NOP			; ef60  00		.
	NOP			; ef61  00		.
	NOP			; ef62  00		.
	NOP			; ef63  00		.
	NOP			; ef64  00		.
	NOP			; ef65  00		.
	NOP			; ef66  00		.
	NOP			; ef67  00		.
	NOP			; ef68  00		.
	NOP			; ef69  00		.
	NOP			; ef6a  00		.
	NOP			; ef6b  00		.
	NOP			; ef6c  00		.
	NOP			; ef6d  00		.
	NOP			; ef6e  00		.
	NOP			; ef6f  00		.
	NOP			; ef70  00		.
	NOP			; ef71  00		.
	NOP			; ef72  00		.
	NOP			; ef73  00		.
	NOP			; ef74  00		.
	NOP			; ef75  00		.
	NOP			; ef76  00		.
	NOP			; ef77  00		.
	NOP			; ef78  00		.
	NOP			; ef79  00		.
	NOP			; ef7a  00		.
	NOP			; ef7b  00		.
	NOP			; ef7c  00		.
	NOP			; ef7d  00		.
	NOP			; ef7e  00		.
	NOP			; ef7f  00		.
	NOP			; ef80  00		.
	NOP			; ef81  00		.
	NOP			; ef82  00		.
	NOP			; ef83  00		.
	NOP			; ef84  00		.
	NOP			; ef85  00		.
	NOP			; ef86  00		.
	NOP			; ef87  00		.
	NOP			; ef88  00		.
	NOP			; ef89  00		.
	NOP			; ef8a  00		.
	NOP			; ef8b  00		.
	NOP			; ef8c  00		.
	NOP			; ef8d  00		.
	NOP			; ef8e  00		.
	NOP			; ef8f  00		.
	NOP			; ef90  00		.
	NOP			; ef91  00		.
	NOP			; ef92  00		.
	NOP			; ef93  00		.
	NOP			; ef94  00		.
	NOP			; ef95  00		.
	NOP			; ef96  00		.
	NOP			; ef97  00		.
	NOP			; ef98  00		.
	NOP			; ef99  00		.
	NOP			; ef9a  00		.
	NOP			; ef9b  00		.
	NOP			; ef9c  00		.
	NOP			; ef9d  00		.
	NOP			; ef9e  00		.
	NOP			; ef9f  00		.
	NOP			; efa0  00		.
	NOP			; efa1  00		.
	NOP			; efa2  00		.
	NOP			; efa3  00		.
	NOP			; efa4  00		.
	NOP			; efa5  00		.
	NOP			; efa6  00		.
	NOP			; efa7  00		.
	NOP			; efa8  00		.
	NOP			; efa9  00		.
	NOP			; efaa  00		.
	NOP			; efab  00		.
	NOP			; efac  00		.
	NOP			; efad  00		.
	NOP			; efae  00		.
	NOP			; efaf  00		.
	NOP			; efb0  00		.
	NOP			; efb1  00		.
	NOP			; efb2  00		.
	NOP			; efb3  00		.
	NOP			; efb4  00		.
	NOP			; efb5  00		.
	NOP			; efb6  00		.
	NOP			; efb7  00		.
	NOP			; efb8  00		.
	NOP			; efb9  00		.
	NOP			; efba  00		.
	NOP			; efbb  00		.
	NOP			; efbc  00		.
	NOP			; efbd  00		.
	NOP			; efbe  00		.
XEFBF:	NOP			; efbf  00		.
	NOP			; efc0  00		.
	NOP			; efc1  00		.
	NOP			; efc2  00		.
	NOP			; efc3  00		.
	NOP			; efc4  00		.
	NOP			; efc5  00		.
	NOP			; efc6  00		.
	NOP			; efc7  00		.
	NOP			; efc8  00		.
	NOP			; efc9  00		.
	NOP			; efca  00		.
	NOP			; efcb  00		.
	NOP			; efcc  00		.
	NOP			; efcd  00		.
	NOP			; efce  00		.
	NOP			; efcf  00		.
	NOP			; efd0  00		.
	NOP			; efd1  00		.
	NOP			; efd2  00		.
	NOP			; efd3  00		.
	NOP			; efd4  00		.
	NOP			; efd5  00		.
	NOP			; efd6  00		.
	NOP			; efd7  00		.
	NOP			; efd8  00		.
	NOP			; efd9  00		.
	NOP			; efda  00		.
	NOP			; efdb  00		.
	NOP			; efdc  00		.
	NOP			; efdd  00		.
	NOP			; efde  00		.
	NOP			; efdf  00		.
	NOP			; efe0  00		.
	NOP			; efe1  00		.
	NOP			; efe2  00		.
	NOP			; efe3  00		.
	NOP			; efe4  00		.
	NOP			; efe5  00		.
	NOP			; efe6  00		.
	NOP			; efe7  00		.
	NOP			; efe8  00		.
	NOP			; efe9  00		.
	NOP			; efea  00		.
	NOP			; efeb  00		.
	NOP			; efec  00		.
	NOP			; efed  00		.
	NOP			; efee  00		.
	NOP			; efef  00		.
	NOP			; eff0  00		.
	NOP			; eff1  00		.
	NOP			; eff2  00		.
	NOP			; eff3  00		.
	NOP			; eff4  00		.
	NOP			; eff5  00		.
	NOP			; eff6  00		.
	NOP			; eff7  00		.
	NOP			; eff8  00		.
	NOP			; eff9  00		.
	NOP			; effa  00		.
	NOP			; effb  00		.
	NOP			; effc  00		.
	NOP			; effd  00		.
XEFFE:	NOP			; effe  00		.
	NOP			; efff  00		.
