/* timer.s - run code off timer interrupts in KL10B exec mode
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
	pushj	SP,_itrin	; initialize interrupts
	pushj	SP,_icini	; initialize interval counter

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

; main()
	.globl	main
	.type	main,@function
main:

; Output the characters in a string, one at a time
; triggered by interval counter interrupts.

	move	7,.Lhello	; move string pointer to AC7
	jrst	3f

1:	move	1,_iccnt	; load AC1 with current interval counter interrupt count
2:	camn	1,_iccnt	; loop until _iccnt has changed
	jrst	2b

	pushj	SP,putchar	; print character in AC0 to the console
	ibp	7		; increment string pointer

3:	ldb	0,7		; load AC0 with next character from string
	jumpn	0,1b		; continue loop if AC0 is not NUL
	popj	SP,
	.size	main,.-main

; static const char *.Lhello = "Hello, World!\r\n"
	.section .rodata
	.p2align 3
	.type	.Lhello,@object
.Lhello:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"Hello, World!\r\n\0"
	.size	.Lhello,.-.Lhello

	.text

; _icini - interval counter initialization
; see $MTROP and $MTRON in subkl.seq
	.globl	_icini
	.type	_icini,@function
_icini:
	cono	MTR,0		; clear interrupt assignment
	cono	TIM,0400000	; clear timer
	move	0,.Licini_vec	; [JSR _icisr]
	movem	0,0514		; set up interval counter vector
	setzm	_iccnt		; clear interval counter interrupt count
	cono	TIM,ICCLR|ICON|ICOFF|ICPRD	; enable timer
	cono	MTR,1		; on PIL 1
	popj	SP,
	.size	_icini,.-_icini

	.type	.Licini_vec,@function
.Licini_vec:
	jsr	_icisr
	.size	.Licini_vec,.-.Licini_vec

; _icisr - interval counter interrupt service routine
; see $MTRIR in subkl.seq
	.globl	_icisr
	.type	_icisr,@function
_icisr:
0:	nop			; JSR stores return PC word here
	cono	MTR,0		; clear meter (set IC PIL to 0)
	cono	TIM,ICON|ICOFF|ICPRD	; reset period
	cono	MTR,1		; reenable meter (set IC PIL to 1)
	aos	_iccnt		; increment interval counter interrupt count
	jen	@0b		; resume via PC word stored at entry
	.size	_icisr,.-_icisr

; unsigned int _iccnt // interval counter interrupt count
	.bss
	.p2align 3
	.type	 _iccnt,@object
_iccnt:
	.pdp10_word 0
	.size	_iccnt,.-_iccnt

	.text

; _itrin - interrupt routine initialization
; see $ITRIN and $KL10 in subkl.seq
	.globl	_itrin
	.type	_itrin,@function
_itrin:
	cono	PI,LRQCLR|LPICLR|LCHNOF|LPIOFF	; CLEAR PI SYSTEM, CHNL & REQ PEND
	cono	PI,LCHNON|LPION|LPICH1	; enable PI and PIL 1
	popj	SP,
	.size	_itrin,.-_itrin

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
