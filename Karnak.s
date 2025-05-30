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
	mov r0,#2048
	str r0,decoded
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
	moveq r1,#0x10
	strbeq r1,adpcmIndex
	moveq r1,#2048
	streq r1,decoded
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
	movne r0,r0,lsr#4			;@ Not sure which nybble is first.
	and r0,r0,#0xF
	strb r0,adpcmIn
	ldrb r1,adpcmIndex
	adr r2,dialogic_ima_step
	ldr r2,[r2,r1,lsl#2]

	movs r0,r0,lsl#29
	mov r0,r0,lsr#29
	adr r3,ima_index_shift
	ldrsb r3,[r3,r0]
	mov r0,r0,lsl#1
	add r0,r0,#1
	rsbcs r0,r0,#0

	adds r1,r1,r3
	movmi r1,#0
	cmp r1,#48
	movpl r1,#48
	strb r1,adpcmIndex

	mul r2,r0,r2
	ldr r0,decoded
	adds r0,r0,r2,asr#3
	movmi r0,0
	cmp r0,#4096
	ldrpl r0,=4095
	str r0,decoded

	bx lr
;@----------------------------------------------------------------------------
karnakADPCMR:				;@ 0xD9 out r0=decoded pcm data
;@----------------------------------------------------------------------------
	ldr r0,decoded
	mov r0,r0,lsr#4
	bx lr
;@----------------------------------------------------------------------------
dialogic_ima_step: // 49 entries
	.long 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45
	.long 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143
	.long 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449
	.long 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552
ima_index_shift:
	.byte -1, -1, -1, -1, 2, 4, 6, 8

timerCounter:
	.long 0
timerBackup:
	.long 0
decoded:
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
