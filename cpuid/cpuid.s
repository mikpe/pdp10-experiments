/* cpuid.s - detect the processor generation (PDP6/KA10/KI10/KL10/KL10B/XKL-1)
   Copyright (C) 2025 Mikael Pettersson <mikpelinux@gmail.com>.

   This file is part of pdp10-experiments.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the license, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; see the file COPYING3.  If not,
   see <http://www.gnu.org/licenses/>.  */

/* NOTES:

   - This must be linked to reside in section 0, page 1 or above.
     For example, ld -Ttext=0x1000 -e _start puts it in section 0 page 1
     without the ELF header mapped first.
*/

	.text
	.p2align 3

; register (accumulator) aliases
.equiv SP, 017		; stack pointer

; Device codes
.equiv APR, 0000	; arithmetic processor
.equiv PI,  0004	; priority interrupts
.equiv PAG, 0010	; pager
.equiv CCA, 0014	; cache sweeper
.equiv TIM, 0020	; timing
.equiv MTR, 0024	; meters
.equiv DTE, 0200	; 1st DTE20 (200, 204, 210, 214)

; KL10 APR CONO assignments
.equiv IOCLR,  0200000	; clear all I/O devices
.equiv LAPRP1, 0000001	; APR PI channel 1
.equiv LAPRAL, 0127760	; clear all error flags & enable

; PI CONO assignments
.equiv LEVNPA, 0400000	; WRITE EVEN PARITY ADDRESS
.equiv LEVNPD, 0200000	; WRITE EVEN PARITY DATA
.equiv LEVNCD, 0100000	; WRITE EVEN CACHE DIRECTORY PARITY *P0
.equiv LRQCLR, 0020000	; DROP INTERRUPT ON SELECTED CHANNEL
.equiv LPICLR, 0010000	; CLEAR PI SYSTEM
.equiv LREQSE, 0004000	; REQUEST INTERRUPT ON SELECTED CHANNEL
.equiv LCHNON, 0002000	; TURN ON SELECTED CHANNEL
.equiv LCHNOF, 0001000	; TURN OFF SELECTED CHANNEL
.equiv LPIOFF, 0000400	; TURN OFF PI SYSTEM
.equiv LPION,  0000200	; TURN ON PI SYSTEM
.equiv LPICH1, 0000100	; PI CHANNEL 1
.equiv LPICH7, 0000001	; PI CHANNEL 7
.equiv LPICHA, 0000177	; ALL PI CHANNELS

; CONO DTE, commands
.equiv DONG11, 020000	; 11 DOORBELL (FROM THE 10)
.equiv DNG10C, 001000	; 10 DOORBELL CLEAR

; CONO MTR assignments
.equiv TBOFF,  0004000	; TIME BASE - TURN OFF
.equiv TBON,   0002000	; TIME BASE - TURN ON
.equiv TBCLR,  0001000	; TIME BASE - CLR
.equiv ICPIL,  0000007	; INTERVAL COUNTER - PRIORITY INTERRUPT LEVEL

; CONO TIM assignments
.equiv ICCLR,  0400000	; INTERVAL COUNTER - CLR
.equiv ICON,   0040000	; INTERVAL COUNTER - TURN ON
.equiv ICOFF,  0020000	; INTERVAL COUNTER - CLR DONE & OVERFLOW
.equiv ICPMSK, 0007777	; INTERVAL COUNTER - PERIOD MASK
.equiv ICPRD,  0003720	; INTERVAL COUNTER - 50 Hz PERIOD

; EPT offsets
.equiv LAROVT, 0421	; ARITHMETIC OVERFLOW TRAP INSTRUCTION
.equiv LPDOVT, 0422	; PUSHDOWN OVERFLOW TRAP INSTRUCTION
.equiv LTRP3T, 0423	; TRAP 3 TRAP INSTRUCTION
.equiv LTBASH, 0510	; TIME-BASE DOUBLEWORD, HIGH
.equiv LTBASL, 0511	; TIME-BASE DOUBLEWORD, LOW
.equiv LPRFMH, 0512	; PERFORMANCE ANALYSIS, HI
.equiv LPRFML, 0513	; PERFORMANCE ANALYSIS, LO
.equiv ICINT,  0514	; INTERVAL COUNTER INTERRUPT INSTRUCTION

; DTE20 EPT parameters
.equiv $DTFLG, 0444	; DTE20 OPERATION COMPLETE FLAG
.equiv $DTCLK, 0445	; DTE20 CLOCK INTERRUPT FLAG
.equiv DTT11,  0447	; DTE20 10 TO 11 ARGUMENT
.equiv $DTF11, 0450	; DTE20 11 TO 10 ARGUMENT
.equiv $DTCMD, 0451	; DTE20 TO 11 COMMAND WORD
.equiv $DTSEQ, 0452	; DTE20 OPERATION SEQUENCE NUMBER
.equiv $DTOPR, 0453	; DTE20 OPERATIONAL DTE #
.equiv DTCHR,  0454	; DTE20 LAST TYPED CHARACTER
.equiv DTMTD,  0455	; DTE20 MONITOR TTY OUTPUT COMPLETE FLAG
.equiv DTMTI,  0456	; DTE20 MONITOR TTY INPUT FLAG
.equiv DTSWR,  0457	; DTE20 10 SWITCH REGISTER

; see klad.sources/sublkl.seq

	.globl	_start
	.type	_start,@function
_start:
	; CPU initialization
	; c.f $PGMIN and $PGMN1
	cono	PI,LPICLR	; clear PI (interrupts) system
	cono	APR,IOCLR	; clear I/O
	jrst	2,@_clrflgs	; clear PC flags
2:	move	SP,_stackptr0	; initialize call stack

	; device initialization
	; c.f. PGINGO
	pushj	SP,_dteini	; initialize DTE20 console

	; call the application main
	pushj	SP,main

	halt	0604460	; "PDP" in DEC SIXBIT
	.size	_start,.-_start

	.section .rodata
	.p2align 3
	.type	_clrflgs,@object
_clrflgs:
	.pdp10_hword	0,2b
	.size	_clrflgs,.-_clrflgs
	.text

; initial stack pointer and stack area
; see PLIST in subkl.seq
.equiv STKSIZ, 0200
	.section .rodata
	.p2align 3
	.type	_stackptr0,@object
_stackptr0:
	.pdp10_hword	-STKSIZ,_stack
	.size	_stackptr0,.-_stackptr0

	.bss
	.p2align 3
	.type	 _stack,@object
_stack:
	.skip	STKSIZ*4*2
	.size	_stack,.-_stack

	.text

.equiv PDP6,   01
.equiv KA10,   02
.equiv KI10,   03
.equiv KL10,   04
.equiv KL10B,  05
.equiv KS10,   06
.equiv XKL1,   07

; main()
	.globl	main
	.type	main,@function
main:
	pushj	SP,cpuid
	caie	0,KL10B
	halt	.		; not a KL10B
	move	0,.Lhello
	pushj	SP,_puts
	popj	SP,
	.size	main,.-main

; static const char *.Lhello = "Hello from a KL10B!\r\n"
	.section .rodata
	.p2align 3
	.type	.Lhello,@object
.Lhello:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"Hello from a KL10B!\r\n\0"
	.size	.Lhello,.-.Lhello

	.text

; unsigned int cpuid(void) // detect processor generation
; see 2.15.1 Processor Identification in the Toad-1 Architecture manual
	.globl	cpuid
	.type	cpuid,@function
cpuid:
	jfcl	017,1f		; Clear flags
1:	jrst	2f		; Change PC
2:	jfcl	1,.PDP6		; PDP-6 has PC Change flag
	movni	1,1		; Others do not.  Make AC1 all 1s
	aobjn	1,3f		; Increment both halves
3:	jumpn	1,.KA10		; KA10 carries to left half
	blt	1,0		; Try BLT. Source=0; Dest=0.  AC1 must not be 0
	jumpe	1,.KI10		; KI10 if AC1 = 0
	movsi	1,0400000	; Largest negative number
	adjbp	1,4f		; [430100,,0] Check what this does (*)
	camn	1,4f		; [430100,,0] The KL won't change this
	jrst	.KL10		; This must be a KL10
	movsi	1,0450000	; A one-word global byte pointer
	ibp	1		; What does this do?
	came	1,5f		; [450000,,0] The KS doesn't change this
	jrst	.XKL1		; This must be an XKL-1
	jrst	.KS10		; Otherwise, it's a KS10

.PDP6:	movei	0,PDP6
	jrst	9f
.KA10:	movei	0,KA10
	jrst	9f
.KI10:	movei	0,KI10
	jrst	9f
.KS10:	movei	0,KS10
	jrst	9f
.XKL1:	; Either the code from the Toad-1 manual is wrong, or
	; klh10 doesn't implement the KL10 quirk (*). The end
	; result is that klh10 is mis-labelled as XKL-1. So
	; we assume KL10 instead.
	; FALLTHROUGH
.KL10:	movei	0,KL10

	blki	APR,1		; read APRID into AC1
	movs	2,1		; swap halves and put in AC2

	andi	1,0040000	; mask out XAH bit (extended KL10)
	jumpe	9f		; if not set, not a KL10B
	andi	2,0200000	; mask out XA bit (microcode handles extended addresses)
	jumpe	9f		; if not set, not a KL10B

	movei	0,KL10B		; both set, it's a KL10B

9:	popj	SP,

4:	.pdp10_hword 0430100,0
5:	.pdp10_hword 0450000,0

	.size	cpuid,.-cpuid

; _puts(const char *s)
; In: AC0 - 9-bit byte pointer to string to print to the console
; Note: unlike puts() this does not automatically output a trailing newline
	.globl	_puts
	.type	_puts,@function
_puts:
	move	7,0		; move string pointer to AC7
	jrst	2f
1:	pushj	SP,putchar	; print character in AC0 to the console
	ibp	7		; increment string pointer
2:	ldb	0,7		; load AC0 with next character from string
	jumpn	0,1b		; continue loop if AC0 is not NUL
	popj	SP,
	.size	_puts,.-_puts

; putchar(int ch)
; In: AC0 - ASCII code to print to the console
; see $DTEXX in subkl.seq
	.globl	putchar
	.type	putchar,@function
putchar:
	setzm	$DTFLG		; clear interrupt flag
	movem	0,$DTCMD	; set up command word
	setzm	$DTF11		; clear response word
	aos	$DTSEQ		; increment operation count
; note: the next instruction is modified by $DTEINI
$$DTE0:	cono	DTE,DONG11	; ring bell the 11
1:	skipn	$DTFLG		; wait for DTE20 comm interrupt
	jrst	1b
	setzm	$DTFLG		; clear interrupt flag
	move	0,$DTF11	; put response in AC0
	popj	SP,
	.size	putchar,.-putchar

; _dteini() // DTE20 initialization
; see $DTEIN in subkl.seq
	.globl	_dteini
	.type	_dteini,@function
_dteini:
	setzm	0140
	setzm	$DTFLG
	move	0,.Ldteini_blt1	; [0140,,0141]
	blt	0,0177		; clear DTE20 EPT locations
	move	0,.Ldteini_blt2	; [$DTFLG,,$DTCLK]
	blt	0,$DTSEQ	; clear DTE20 communications area
	move	0,$DTOPR	; get operational DTE #
	orm	0,$$DTE0	; insert into DTE20 I/O instructions
	popj	SP,
	.size	_dteini,.-_dteini

	.section .rodata
	.p2align 3

	.type	.Ldteini_blt1,@object
.Ldteini_blt1:
	.pdp10_hword	0140,0141	; word to clear DTE20 EPT locations
	.size	.Ldteini_blt1,.-.Ldteini_blt1

	.type	.Ldteini_blt2,@object
.Ldteini_blt2:
	.pdp10_hword	$DTFLG,$DTCLK	; word to clear DTE20 communications area
	.size	.Ldteini_blt2,.-.Ldteini_blt2

	.text
