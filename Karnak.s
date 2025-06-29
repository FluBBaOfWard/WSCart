#ifdef __arm__

#include "../Sphinx/Sphinx.i"

	.global karnakReset
	.global karnakTimerR
	.global karnakTimerW
	.global karnakADPCMR
	.global karnakADPCMW

	.syntax unified
	.arm

	.section .ewram,"ax"
	.align 2

;@----------------------------------------------------------------------------
karnakReset:
;@----------------------------------------------------------------------------
	mov r0,#0
	strb r0,[spxptr,#wsvCartTimer]
	strb r0,adpcmOddEven
	strb r0,adpcmIndex
	mov r0,#0x80<<23
	str r0,accumulator
	bx lr
;@----------------------------------------------------------------------------
timerUpdate:				;@ r0=number of 384KHz clocks.
;@----------------------------------------------------------------------------
	ldr r1,timerCounter
	subs r1,r1,r0
	ldrls r2,timerBackup
	addls r1,r1,r2
	str r1,timerCounter
	bxhi lr
	mov r0,#1
	stmfd sp!,{lr}
	bl setInterruptExternal
	ldmfd sp!,{lr}
	mov r0,#0
	b setInterruptExternal
;@----------------------------------------------------------------------------
karnakTimerR:				;@ 0xD6
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvCartTimer]
	stmfd sp!,{r1,spxptr,lr}
	bl debugIOUnmappedR
	ldmfd sp!,{r0,spxptr,lr}
	bx lr
;@----------------------------------------------------------------------------
karnakTimerW:				;@ 0xD6
;@ ((period + 1) * 2) cartridge clocks, where "one cartridge clock" = 384KHz = 1/8th CPU clock.
;@----------------------------------------------------------------------------
	ands r2,r0,#0x80			;@ Timer on?
	adrne r2,timerUpdate
	strbeq r2,adpcmOddEven
	moveq r1,#0
	strbeq r1,adpcmIndex
	moveq r1,#0x80<<23
	streq r1,accumulator
	ldr r1,=cartUpdatePtr
	str r2,[r1]
	strb r0,[spxptr,#wsvCartTimer]
	and r2,r0,#0x7F
	add r2,r2,#1
	mov r2,r2,lsl#1
	str r2,timerCounter
	str r2,timerBackup
	bx lr
;@----------------------------------------------------------------------------
karnakADPCMW:					;@ 0xD8 r0=adpcm data
;@----------------------------------------------------------------------------
	ldrb r1,adpcmOddEven
	eors r1,r1,#1
	strb r1,adpcmOddEven
	movne r0,r0,lsr#4
	and r0,r0,#0xF
	strb r0,adpcmIn
	movs r0,r0,lsl#29
	mov r0,r0,lsr#29
	ldrb r1,adpcmIndex
	adr r2,upd775x_step
	add r2,r2,r1,lsl#3
	ldrb r2,[r2,r0]
	rsbcs r2,r2,#0

	adr r3,upd775x_index_shift
	ldrsb r3,[r3,r0]

	adds r1,r1,r3
	movmi r1,#0
	cmp r1,#15
	movpl r1,#15
	strb r1,adpcmIndex

	ldr r0,accumulator
	add r0,r0,r2,lsl#22
	str r0,accumulator

	bx lr
;@----------------------------------------------------------------------------
karnakADPCMR:				;@ 0xD9 out r0=decoded pcm data
;@----------------------------------------------------------------------------
	ldr r0,accumulator
	movs r0,r0,asr#23
	bxpl lr
	mov r0,r0,lsl#24
	eor r0,r0,#0x80000000
	mov r0,r0,asr#31
	bx lr
;@----------------------------------------------------------------------------

upd775x_step:
	.byte  0,  0,  1,  2,  3,   5,   7,  10
	.byte  0,  1,  2,  3,  4,   6,   8,  13
	.byte  0,  1,  2,  4,  5,   7,  10,  15
	.byte  0,  1,  3,  4,  6,   9,  13,  19
	.byte  0,  2,  3,  5,  8,  11,  15,  23
	.byte  0,  2,  4,  7, 10,  14,  19,  29
	.byte  0,  3,  5,  8, 12,  16,  22,  33
	.byte  1,  4,  7, 10, 15,  20,  29,  43
	.byte  1,  4,  8, 13, 18,  25,  35,  53
	.byte  1,  6, 10, 16, 22,  31,  43,  64
	.byte  2,  7, 12, 19, 27,  37,  51,  76
	.byte  2,  9, 16, 24, 34,  46,  64,  96
	.byte  3, 11, 19, 29, 41,  57,  79, 117
	.byte  4, 13, 24, 36, 50,  69,  96, 143
	.byte  4, 16, 29, 44, 62,  85, 118, 175
	.byte  6, 20, 36, 54, 76, 104, 144, 214
upd775x_index_shift:
	.byte -1, -1, 0, 0, 1, 2, 2, 3

timerCounter:
	.long 0
timerBackup:
	.long 0
accumulator:
	.long 0
adpcmOddEven:
	.byte 0
adpcmIndex:
	.byte 0
adpcmIn:
	.byte 0
	.align 2

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
