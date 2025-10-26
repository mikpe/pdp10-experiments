/* date.s - retrieve date and time from the DTE20
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

; $DTCMD values
.equiv DTECMD_RTM, (013<<8)	; Get date/time info
.equiv EPTOFF, 0170		; DTE20 #3 Control Block (assumed to not exist)

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

; main()
	.globl	main
	.type	main,@function
main:
	;; ask DTE20 for date/time, store in spare EPT slots
	movei	0,EPTOFF
	lsh	0,16		; put destination EPT offset in bits 4..19
	ori	0,DTECMD_RTM	; insert command code
	pushj	SP,$dtexx

	move	0,.Lraw
	pushj	SP,_puts

	move	0,EPTOFF+0
	pushj	SP,puto
	pushj	SP,putnl
	move	0,EPTOFF+1
	pushj	SP,puto
	pushj	SP,putnl
	move	0,EPTOFF+2
	pushj	SP,puto
	pushj	SP,putnl

	move	0,EPTOFF+0
	lsh	0,-16		; extract valid flag
	skipn	0		; if valid / non-zero, skip subsequent halt
	halt	.

	move	0,.Ldate
	pushj	SP,_puts

	move	0,EPTOFF+0
	andi	0,65535		; extract year
	pushj	SP,putud
	movei	0,'-'
	pushj	SP,$dtexx

	move	0,EPTOFF+1
	lsh	0,-24		; extract month (0=Jan)
	addi	0,1
	pushj	SP,putud2
	movei	0,'-'
	pushj	SP,$dtexx

	move	0,EPTOFF+1
	lsh	0,-16
	andi	0,255		; extract day (0=1st)
	addi	0,1
	pushj	SP,putud2
	pushj	SP,putnl

	move	0,.Ltime
	pushj	SP,_puts

	move	0,EPTOFF+2
	lsh	0,-15		; extract seconds since midnight

	move	1,0		; <seconds since midnight> -> <minutes since midnight, seconds in minute>
	setz	0,
	divi	0,60
	push	SP,1		; save seconds in minute

	move	1,0		; <minutes since midnight> -> <hours since midnight, minutes in hour>
	setz	0,
	divi	0,60
	push	SP,1		; save minutes in hour

	pushj	SP,putud2	; print hour
	movei	0,':'
	pushj	SP,$dtexx
	pop	SP,0		; restore minutes
	pushj	SP,putud2
	movei	0,':'
	pushj	SP,$dtexx
	pop	SP,0		; restore seconds
	pushj	SP,putud2
	pushj	SP,putnl

	move	0,.Lwkday
	pushj	SP,_puts

	move	0,EPTOFF+1
	lsh	0,-8
	andi	0,255		; extract weekday (0=Mon)
	addi	0,1
	pushj	SP,putud
	pushj	SP,putnl

	move	0,.Lt20tz
	pushj	SP,_puts

	move	0,EPTOFF+1
	andi	0,127		; extract timezone
	lsh	0,29
	ash	0,-29		; sign-extend
	pushj	SP,putsd
	pushj	SP,putnl

	popj	SP,
	.size	main,.-main

	.section .rodata

	.p2align 3
	.type	.Lraw,@object
.Lraw:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"DTECMD_RTM raw result:\r\n\0"
	.size	.Lraw,.-.Lraw

	.p2align 3
	.type	.Ldate,@object
.Ldate:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"Date:  \0"
	.size	.Ldate,.-.Ldate

	.p2align 3
	.type	.Ltime,@object
.Ltime:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"Time:  \0"
	.size	.Ltime,.-.Ltime

	.p2align 3
	.type	.Lwkday,@object
.Lwkday:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"Wkday: \0"
	.size	.Lwkday,.-.Lwkday

	.p2align 3
	.type	.Lt20tz,@object
.Lt20tz:
	.pdp10_bptr	1f
1:	.pdp10_ascii	"T20TZ: \0"
	.size	.Lt20tz,.-.Lt20tz

	.text

; putsd(int w)
; In: AC0 - signed word to print to the console in decimal
	.globl	putsd
	.type	putsd,@function
putsd:
	jumpge	0,1f		; if non-negative, jump

	push	SP,0		; save number
	movei	0,'-'
	pushj	SP,$dtexx
	pop	SP,0		; restore number
	movn	0,0

1:	pushj	SP,putud
	popj	SP,
	.size	putsd,.-putsd

; putud2(unsigned int w)
; Like putud(), but emit leading '0' if w < 10
	.globl	putud2
	.type	putud2,@function
putud2:
	cail	0,10		; if !(AC0 < 10)
	jrst	1f		; .. then jump over next block

	push	SP,0		; save word to print
	movei	0,'0'
	pushj	SP,$dtexx
	pop	SP,0		; restore word to print

1:	pushj	SP,putud
	popj	SP,
	.size	putud2,.-putud2

; putud(unsigned int w)
; In: AC0 - word to print to the console in decimal
	.globl	putud
	.type	putud,@function
putud:
	; compute <0,AC0> / 10 -> <quotient, remainder>
	move	1,0
	setz	0,
	divi	0,10

	; if quotient is zero don't recurse
	jumpe	0,1f

	; quotient is non-zero, recurse to emit it
	push	SP,1		; save remainder in AC1
	pushj	SP,putud	; recursively emit quotient
	pop	SP,1		; restore remainder in AC1

	; emit remainder digit in AC1
1:	move	0,1
	addi	0,'0'
	pushj	SP,$dtexx

	popj	SP,
	.size	putud,.-putud

; puto(unsigned int w)
; In: AC0 - word to print to the console in octal high,,low format
	.globl	puto
	.type	puto,@function
puto:
	move	7,0		; move word to AC7
	movei	6,12		; load AC6 with digit counter

0:	rot	7,3		; rotate AC7 3 bits left
	move	0,7
	andi	0,7		; extract low 3 bits
	addi	0,'0'		; convert to ASCII
	pushj	SP,$dtexx	; and output

	subi	6,1		; decrement digit counter

	; if digit counter == 6, print ",," and continue loop
	caie	6,6		; skip jump if digit counter == 6
	jrst	1f
	movei	0,','
	pushj	SP,$dtexx
	movei	0,','
	pushj	SP,$dtexx
	jrst	0b

	; if digit counter != 0 continue loop
1:	jumpn	6,0b

	popj	SP,
	.size	puto,.-puto

; putnl() // output CR NL
	.globl	putnl
	.type	putnl,@function
putnl:
	movei	0,'\r'
	pushj	SP,$dtexx
	movei	0,'\n'
	pushj	SP,$dtexx
	popj	SP,
	.size	putnl,.-putnl

; _puts(const char *s)
; In: AC0 - 9-bit byte pointer to string to print to the console
; Note: unlike puts() this does not automatically output a trailing newline
	.globl	_puts
	.type	_puts,@function
_puts:
	move	7,0		; move string pointer to AC7
	jrst	2f
1:	pushj	SP,$dtexx	; print character in AC0 to the console
	ibp	7		; increment string pointer
2:	ldb	0,7		; load AC0 with next character from string
	jumpn	0,1b		; continue loop if AC0 is not NUL
	popj	SP,
	.size	_puts,.-_puts

; $dtexx(unsigned w)
; In: W - a word to send to the DTE20 via $DTCMD
; A word < 128 is ASCII to output the the console
; see $DTEXX in subkl.seq
	.globl	$dtexx
	.type	$dtexx,@function
$dtexx:
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
	.size	$dtexx,.-$dtexx

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
