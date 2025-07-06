#ifdef __arm__

#include "../WSEEPROM/WSEEPROM.i"
#include "WSRTC/WSRTC.i"
#include "../Sphinx/Sphinx.i"
#include "../ARMV30MZ/ARMV30MZ.i"

	.global romSpacePtr
	.global gRomSize
	.global romSize
	.global gGameHeader
	.global gGameID
	.global gFileType
	.global cartOrientation
	.global cartEeprom
	.global sramSize
	.global eepromSize
	.global cartUpdatePtr

	.global cartSRAM
	.global cartEepromMem

	.global wsCartReset
	.global resetCartridgeBanks
	.global reBankSwitchAll
	.global cartUpdate

	.syntax unified
	.arm

	.section .ewram,"ax"
	.align 2
;@----------------------------------------------------------------------------
wsCartReset:				;@ r0=
;@----------------------------------------------------------------------------
	stmfd sp!,{v30ptr,lr}
	ldr v30ptr,=V30OpTable

	bl fixRomSizeAndPtr

	bl resetCartridgeBanks

	ldr r0,[v30ptr,#v30MemTblInv-10*4]	;@ MemMap

	ldr r3,=0xFFFF0				;@ Header offset
	add r3,r0,r3
	str r3,gGameHeader
	ldrb r0,[r3,#0x8]			;@ Game ID
	strb r0,gGameID
	ldrb r2,[r3,#0xB]			;@ NVRAM size
	mov r0,#0					;@ r0 = sram size
	mov r1,#0					;@ r1 = eeprom size
	cmp r2,#0x01				;@ 256kbit sram
	cmpne r2,#0x02				;@ 256kbit sram
	moveq r0,#0x8000
	cmp r2,#0x03				;@ 1Mbit sram
	moveq r0,#0x20000
	cmp r2,#0x04				;@ 2Mbit sram
	moveq r0,#0x40000
	cmp r2,#0x05				;@ 4Mbit sram
	moveq r0,#0x80000
	cmp r2,#0x10				;@ 1kbit eeprom
	moveq r1,#0x80
	cmp r2,#0x20				;@ 16kbit eeprom
	moveq r1,#0x800
	cmp r2,#0x50				;@ 8kbit eeprom
	moveq r1,#0x400
	str r0,sramSize
	str r1,eepromSize

	ldrb r0,[r3,#0xC]			;@ Flags
	and r0,r0,#1				;@ Orientation
	strb r0,cartOrientation

	ldrb r0,[r3,#0xD]			;@ Mapper? (RTC present)
	strb r0,rtcPresent

	ldr r3,=gFileType
	ldrb r3,[r3]
	ands r2,r0,#1				;@ RTC?
	ldrne r2,=rtcUpdate
	str r2,cartUpdatePtr
	cmp r1,#0					;@ Does the cart use EEPROM?
	ldrne r0,=Luxsor2001R		;@ Yes, use old Mapper Chip.
	ldrne r1,=Luxsor2001W
	movne r2,#0x10
	ldreq r0,=Luxsor2003R		;@ Nope, use new Mapper Chip.
	ldreq r1,=Luxsor2003W
	moveq r2,#0x20
	cmpeq r3,#HW_POCKETCHALLENGEV2
	ldreq r0,=KarnakR			;@ Some PCV2 games uses Karnak mapper.
	ldreq r1,=KarnakW
	adr r3,cartUnmR
	bl wsvSetCartMap

	bl eepromReset
	bl rtcReset
	bl karnakReset

	ldmfd sp!,{v30ptr,lr}
	bx lr

;@----------------------------------------------------------------------------
cartUpdate:				;@ r0=number of 384KHz clocks.
;@----------------------------------------------------------------------------
	ldr r1,cartUpdatePtr
	cmp r1,#0
	bxeq lr
	bx r1
;@----------------------------------------------------------------------------
fixRomSizeAndPtr:
;@----------------------------------------------------------------------------
	ldr r0,romSize
	sub r1,r0,#1
	orr r1,r1,r1,lsr#1
	orr r1,r1,r1,lsr#2
	orr r1,r1,r1,lsr#4
	orr r1,r1,r1,lsr#8
	orr r1,r1,r1,lsr#16
	add r1,r1,#1				;@ RomSize Power of 2

	movs r2,r1,lsr#16			;@ 64kB blocks.
	subne r2,r2,#1
	str r2,romMask				;@ romMask=romBlocks-1

	ldr r2,romSpacePtr
	add r2,r2,r0
	sub r2,r2,r1
	str r2,romPtr
	sub r2,r2,#0x10000
	str r2,romPtr1
	sub r2,r2,#0x10000
	str r2,romPtr2
	sub r2,r2,#0x10000
	str r2,romPtr3
	sub r2,r2,#0x10000
	str r2,romPtr4

	bx lr
;@----------------------------------------------------------------------------
resetCartridgeBanks:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr spxptr,=sphinx0
	mov r0,#0
	bl cartWWFlashW
	bl flashMemReset
	mov r0,#0xFF
	bl BankSwitch4_F_W
	mov r0,#0xFF
	bl BankSwitch1_W
	mov r0,#0xFF
	bl BankSwitch2_W
	mov r0,#0xFF
	bl BankSwitch3_W
	mov r0,#0x3
	strb r0,[spxptr,#wsvBnk1SlctX+1]
	strb r0,[spxptr,#wsvBnk2SlctX+1]
	strb r0,[spxptr,#wsvBnk3SlctX+1]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
reBankSwitchAll:
;@----------------------------------------------------------------------------
	stmfd sp!,{v30ptr,lr}
	ldr v30ptr,=V30OpTable
	bl reBankSwitch4_F
	bl reBankSwitch1
	bl reBankSwitch2
	bl reBankSwitch3
	ldmfd sp!,{v30ptr,lr}
	bx lr
;@----------------------------------------------------------------------------
reBankSwitch4_F:			;@ 0x40000-0xFFFFF
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk0SlctX]
;@----------------------------------------------------------------------------
BankSwitch4_F_W:			;@ 0x40000-0xFFFFF
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	and r0,r0,#0x3F
	strb r0,[spxptr,#wsvBnk0SlctX]
	orr r0,r0,#0x40000000

	ldr r1,romMask
	ldr r2,romPtr4
	add lr,v30ptr,#v30MemTblInv-5*4
tbLoop2:
	and r3,r1,r0,ror#28
	add r3,r2,r3,lsl#16		;@ 64kB blocks.
	sub r2,r2,#0x10000
	str r3,[lr],#-4
	adds r0,r0,#0x10000000
	bcc tbLoop2

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
BankSwitch1_H_W:			;@ 0x10000-0x1FFFF
;@----------------------------------------------------------------------------
	and r0,r0,#0x3
	strb r0,[spxptr,#wsvBnk1SlctX+1]
;@----------------------------------------------------------------------------
reBankSwitch1:				;@ 0x10000-0x1FFFF
;@----------------------------------------------------------------------------
	ldrh r0,[spxptr,#wsvBnk1SlctX]
	ldrb r1,[spxptr,#wsvBank1Map]
	tst r1,#1
	bne BankSwitch1F_W
;@----------------------------------------------------------------------------
BankSwitch1_W:				;@ 0x10000-0x1FFFF
BankSwitch1_L_W:			;@ 0x10000-0x1FFFF
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvBnk1SlctX]

	ldr r1,sramSize
	movs r1,r1,lsr#16			;@ 64kB blocks.
	subne r1,r1,#1
	and r1,r1,#3				;@ Mask for actual SRAM banks we emulate
	ldr r2,=cartSRAM-0x10000
	and r3,r1,r0
	add r3,r2,r3,lsl#16			;@ 64kB blocks.
	str r3,[v30ptr,#v30MemTblInv-2*4]

	bx lr
;@----------------------------------------------------------------------------
BankSwitch1F_W:				;@ 0x10000-0x1FFFF
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvBnk1SlctX]

	ldr r1,romMask
	ldr r2,romPtr1
	and r3,r1,r0
	add r3,r2,r3,lsl#16			;@ 64kB blocks.
	str r3,[v30ptr,#v30MemTblInv-2*4]

	bx lr
;@----------------------------------------------------------------------------
BankSwitch2_H_W:			;@ 0x20000-0x2FFFF
;@----------------------------------------------------------------------------
	and r0,r0,#0x3
	strb r0,[spxptr,#wsvBnk2SlctX+1]
;@----------------------------------------------------------------------------
reBankSwitch2:				;@ 0x20000-0x2FFFF
;@----------------------------------------------------------------------------
	ldrh r0,[spxptr,#wsvBnk2SlctX]
;@----------------------------------------------------------------------------
BankSwitch2_W:				;@ 0x20000-0x2FFFF
BankSwitch2_L_W:			;@ 0x20000-0x2FFFF
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvBnk2SlctX]

	ldr r1,romMask
	ldr r2,romPtr2
	and r3,r1,r0
	add r3,r2,r3,lsl#16			;@ 64kB blocks.
	str r3,[v30ptr,#v30MemTblInv-3*4]

	bx lr
;@----------------------------------------------------------------------------
BankSwitch3_H_W:			;@ 0x30000-0x3FFFF
;@----------------------------------------------------------------------------
	and r0,r0,#0x3
	strb r0,[spxptr,#wsvBnk3SlctX+1]
;@----------------------------------------------------------------------------
reBankSwitch3:				;@ 0x30000-0x3FFFF
;@----------------------------------------------------------------------------
	ldrh r0,[spxptr,#wsvBnk3SlctX]
;@----------------------------------------------------------------------------
BankSwitch3_W:				;@ 0x30000-0x3FFFF
BankSwitch3_L_W:			;@ 0x30000-0x3FFFF
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvBnk3SlctX]

	ldr r1,romMask
	ldr r2,romPtr3
	and r3,r1,r0
	add r3,r2,r3,lsl#16			;@ 64kB blocks.
	str r3,[v30ptr,#v30MemTblInv-4*4]

	bx lr

;@----------------------------------------------------------------------------
BankSwitch4_F_R:			;@ 0xC0/0xCF
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk0SlctX]
	bx lr
;@----------------------------------------------------------------------------
BankSwitch1_R:				;@ 0xC1/0xD0
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk1SlctX]
	bx lr
;@----------------------------------------------------------------------------
BankSwitch1_H_R:			;@ 0xD1
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk1SlctX+1]
	bx lr
;@----------------------------------------------------------------------------
BankSwitch2_R:				;@ 0xC2/0xD2
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk2SlctX]
	bx lr
;@----------------------------------------------------------------------------
BankSwitch2_H_R:			;@ 0xD3
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk2SlctX+1]
	bx lr
;@----------------------------------------------------------------------------
BankSwitch3_R:				;@ 0xC3/0xD4
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk3SlctX]
	bx lr
;@----------------------------------------------------------------------------
BankSwitch3_H_R:			;@ 0xD5
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBnk3SlctX+1]
	bx lr

;@----------------------------------------------------------------------------
cartGPIODirR:				;@ 0xCC General Purpose I/O enable/dir?, bit 3-0.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvGPIOEnable]
	bx lr
;@----------------------------------------------------------------------------
cartGPIODataR:				;@ 0xCD General Purpose I/O data, bit 3-0.
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvGPIOData]
	bx lr
;@----------------------------------------------------------------------------
cartWWFlashR:				;@ 0xCE WonderWitch Flash/SRAM select
;@----------------------------------------------------------------------------
	ldrb r0,[spxptr,#wsvBank1Map]
	bx lr

;@----------------------------------------------------------------------------
cartGPIODirW:				;@ 0xCC General Purpose I/O direction, bit 3-0.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvGPIOEnable]
	bx lr
;@----------------------------------------------------------------------------
cartGPIODataW:				;@ 0xCD General Purpose I/O data, bit 3-0.
;@----------------------------------------------------------------------------
	strb r0,[spxptr,#wsvGPIOData]
	bx lr
;@----------------------------------------------------------------------------
cartWWFlashW:				;@ 0xCE WonderWitch Flash/SRAM select
;@----------------------------------------------------------------------------
	ldrb r1,[spxptr,#wsvBank1Map]
	and r0,r0,#1
	eors r1,r1,r0
	bxeq lr
	strb r0,[spxptr,#wsvBank1Map]
	tst r0,#1
	ldrne r1,=BankSwitch1F_W
	ldreq r1,=BankSwitch1_W
	stmfd sp!,{lr}
	mov r0,#0xC1
	bl wsvSetIOPortOut
	mov r0,#0xD0
	bl wsvSetIOPortOut
	ldrb r0,[spxptr,#wsvBank1Map]
	bl setSRamArea
	ldmfd sp!,{lr}
	b reBankSwitch1

;@----------------------------------------------------------------------------
extEepromDataLowR:			;@ 0xC4
;@----------------------------------------------------------------------------
	adr eeptr,cartEeprom
	b wsEepromDataLowR
;@----------------------------------------------------------------------------
extEepromDataHighR:			;@ 0xC5
;@----------------------------------------------------------------------------
	adr eeptr,cartEeprom
	b wsEepromDataHighR
;@----------------------------------------------------------------------------
extEepromAdrLowR:			;@ 0xC6
;@----------------------------------------------------------------------------
	adr eeptr,cartEeprom
	b wsEepromAddressLowR
;@----------------------------------------------------------------------------
extEepromAdrHighR:			;@ 0xC7
;@----------------------------------------------------------------------------
	adr eeptr,cartEeprom
	b wsEepromAddressHighR
;@----------------------------------------------------------------------------
extEepromStatusR:			;@ 0xC8
;@----------------------------------------------------------------------------
	adr eeptr,cartEeprom
	b wsEepromStatusR
;@----------------------------------------------------------------------------
extEepromDataLowW:			;@ 0xC4
;@----------------------------------------------------------------------------
	mov r1,r0
	adr eeptr,cartEeprom
	b wsEepromDataLowW
;@----------------------------------------------------------------------------
extEepromDataHighW:			;@ 0xC5
;@----------------------------------------------------------------------------
	mov r1,r0
	adr eeptr,cartEeprom
	b wsEepromDataHighW
;@----------------------------------------------------------------------------
extEepromAdrLowW:			;@ 0xC6
;@----------------------------------------------------------------------------
	mov r1,r0
	adr eeptr,cartEeprom
	b wsEepromAddressLowW
;@----------------------------------------------------------------------------
extEepromAdrHighW:			;@ 0xC7
;@----------------------------------------------------------------------------
	mov r1,r0
	adr eeptr,cartEeprom
	b wsEepromAddressHighW
;@----------------------------------------------------------------------------
extEepromCommandW:			;@ 0xC8
;@----------------------------------------------------------------------------
	mov r1,r0
	adr eeptr,cartEeprom
	b wsEepromCommandW
;@----------------------------------------------------------------------------
eepromReset:
;@----------------------------------------------------------------------------
	ldr r1,eepromSize
	cmp r1,#0
	bxeq lr
	ldr r2,=cartEepromMem
	mov r3,#0					;@ Disallow protect
	adr eeptr,cartEeprom
	b wsEepromReset
;@----------------------------------------------------------------------------
cartEeprom:
	.space wsEepromSize

;@----------------------------------------------------------------------------
rtcStatusR:					;@ 0xCA
;@----------------------------------------------------------------------------
	adr rtcptr,cartRtc
	b wsRtcStatusR
;@----------------------------------------------------------------------------
rtcDataR:					;@ 0xCB
;@----------------------------------------------------------------------------
	adr rtcptr,cartRtc
	b wsRtcDataR
;@----------------------------------------------------------------------------
rtcCommandW:				;@ 0xCA
;@----------------------------------------------------------------------------
	mov r1,r0
	adr rtcptr,cartRtc
	b wsRtcCommandW
;@----------------------------------------------------------------------------
rtcDataW:					;@ 0xCB
;@----------------------------------------------------------------------------
	mov r1,r0
	adr rtcptr,cartRtc
	b wsRtcDataW
;@----------------------------------------------------------------------------
rtcReset:
;@----------------------------------------------------------------------------
	ldrb r0,rtcPresent
	cmp r0,#0
	bxeq lr
	stmfd sp!,{lr}
	adr rtcptr,cartRtc
	ldr r1,=setInterruptExternal
	bl wsRtcReset
	bl getTime					;@ r0 = ??ssMMHH, r1 = ??DDMMYY
	ldmfd sp!,{lr}
	mov r2,r1
	mov r1,r0
	adr rtcptr,cartRtc
	b wsRtcSetDateTime
;@----------------------------------------------------------------------------
rtcUpdate:				;@ r0=number of 384KHz clocks.
;@----------------------------------------------------------------------------
	ldr r1,rtcCounter
	subs r0,r1,r0
	ldrcc r1,=384000				;@ 1 Second in cart clocks (3072000/8).
	addcc r0,r0,r1
	str r0,rtcCounter
	bxcs lr
	adr rtcptr,cartRtc
	b wsRtcUpdate
;@----------------------------------------------------------------------------
cartRtc:
	.space wsRtcSize

;@----------------------------------------------------------------------------
cartUnmR:
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	stmfd sp!,{spxptr,lr}
	bl debugIOUnmappedR
	ldmfd sp!,{spxptr,lr}
	mov r0,#0xFF				;@ 2001, 2003 & Karnak is open bus?
	bx lr
;@----------------------------------------------------------------------------
cartUnmW:					;@ Affects open bus value
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	stmfd sp!,{spxptr,lr}
	bl debugIOUnmappedW
	ldmfd sp!,{spxptr,pc}

;@----------------------------------------------------------------------------


romSpacePtr:
	.long 0
romPtr:
	.long 0
romPtr1:
	.long 0
romPtr2:
	.long 0
romPtr3:
	.long 0
romPtr4:
	.long 0
gRomSize:
romSize:
	.long 0
romMask:
	.long 0
sramSize:
	.long 0
eepromSize:
	.long 0
gGameHeader:
	.long 0
rtcCounter:
	.long 0
cartUpdatePtr:
	.long 0

gGameID:
	.byte 0						;@ Game ID
cartOrientation:
	.byte 0						;@ 1=Vertical, 0=Horizontal
rtcPresent:
	.byte 0						;@ RTC present in cartridge
gFileType:
	.byte HW_WONDERSWAN
;@----------------------------------------------------------------------------
	.section .rodata
	.align 2

Luxsor2001R:
	.long BankSwitch4_F_R		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long BankSwitch1_R			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_R			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_R			;@ 0xC3 Bank switch 0x30000
	.long extEepromDataLowR		;@ 0xC4 ext-eeprom data low
	.long extEepromDataHighR	;@ 0xC5 ext-eeprom data high
	.long extEepromAdrLowR		;@ 0xC6 ext-eeprom address low
	.long extEepromAdrHighR		;@ 0xC7 ext-eeprom address high
	.long extEepromStatusR		;@ 0xC8 ext-eeprom status

	;@ 0xC9-0xCF
	.long cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR
	;@ 0xD0-0xFF Is all cartUnmR

Luxsor2001W:
	.long BankSwitch4_F_W		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long BankSwitch1_W			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_W			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_W			;@ 0xC3 Bank switch 0x30000
	.long extEepromDataLowW		;@ 0xC4 ext-eeprom data low
	.long extEepromDataHighW	;@ 0xC5 ext-eeprom data high
	.long extEepromAdrLowW		;@ 0xC6 ext-eeprom address low
	.long extEepromAdrHighW		;@ 0xC7 ext-eeprom address high
	.long extEepromCommandW		;@ 0xC8 ext-eeprom command
	;@ 0xC9-0xCF
	.long cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW
	;@ 0xD0-0xFF Is all cartUnmW

;@----------------------------------------------------------------------------
Luxsor2003R:
	.long BankSwitch4_F_R		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long BankSwitch1_R			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_R			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_R			;@ 0xC3 Bank switch 0x30000
	.long cartUnmR				;@ 0xC4
	.long cartUnmR				;@ 0xC5
	.long cartUnmR				;@ 0xC6
	.long cartUnmR				;@ 0xC7
	.long cartUnmR				;@ 0xC8
	.long cartUnmR				;@ 0xC9
	.long rtcStatusR			;@ 0xCA RTC status
	.long rtcDataR				;@ 0xCB RTC data read
	.long cartGPIODirR			;@ 0xCC General purpose input/output direction, bit 3-0.
	.long cartGPIODataR			;@ 0xCD General purpose input/output data, bit 3-0.
	.long cartWWFlashR			;@ 0xCE WonderWitch flash
	.long BankSwitch4_F_R		;@ 0xCF Alias to 0xC0

	.long BankSwitch1_R			;@ 0xD0 Alias to 0xC1
	.long BankSwitch1_H_R		;@ 0xD1 2 more bits for 0xC1
	.long BankSwitch2_R			;@ 0xD2 Alias to 0xC2
	.long BankSwitch2_H_R		;@ 0xD3 2 more bits for 0xC2
	.long BankSwitch3_R			;@ 0xD4 Alias to 0xC3
	.long BankSwitch3_H_R		;@ 0xD5 2 more bits for 0xC3
	;@ 0xD6-0xDF
	.long cartUnmR,cartUnmR
	.long cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR
	;@ 0xE0-0xFF Is all cartUnmR

Luxsor2003W:
	.long BankSwitch4_F_W		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long BankSwitch1_W			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_W			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_W			;@ 0xC3 Bank switch 0x30000
	.long cartUnmW				;@ 0xC4
	.long cartUnmW				;@ 0xC5
	.long cartUnmW				;@ 0xC6
	.long cartUnmW				;@ 0xC7
	.long cartUnmW				;@ 0xC8
	.long cartUnmW				;@ 0xC9
	.long rtcCommandW			;@ 0xCA RTC command
	.long rtcDataW				;@ 0xCB RTC data write
	.long cartGPIODirW			;@ 0xCC General purpose input/output direction, bit 3-0.
	.long cartGPIODataW			;@ 0xCD General purpose input/output data, bit 3-0.
	.long cartWWFlashW			;@ 0xCE WonderWitch flash
	.long BankSwitch4_F_W		;@ 0xCF Alias to 0xC0

	.long BankSwitch1_L_W		;@ 0xD0 Alias to 0xC1
	.long BankSwitch1_H_W		;@ 0xD1 2 more bits for 0xC1
	.long BankSwitch2_L_W		;@ 0xD2 Alias to 0xC2
	.long BankSwitch2_H_W		;@ 0xD3 2 more bits for 0xC2
	.long BankSwitch3_L_W		;@ 0xD4 Alias to 0xC3
	.long BankSwitch3_H_W		;@ 0xD5 2 more bits for 0xC3
	;@ 0xD6-0xDF
	.long cartUnmW,cartUnmW
	.long cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW
	;@ 0xE0-0xFF Is all cartUnmW

;@----------------------------------------------------------------------------
KarnakR:
	.long BankSwitch4_F_R		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long BankSwitch1_R			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_R			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_R			;@ 0xC3 Bank switch 0x30000
	.long cartUnmR				;@ 0xC4
	.long cartUnmR				;@ 0xC5
	.long cartUnmR				;@ 0xC6
	.long cartUnmR				;@ 0xC7
	.long cartUnmR				;@ 0xC8
	.long cartUnmR				;@ 0xC9
	.long cartUnmR				;@ 0xCA
	.long cartUnmR				;@ 0xCB
	.long cartGPIODirR			;@ 0xCC General purpose input/output direction, bit 3-0.
	.long cartGPIODataR			;@ 0xCD General purpose input/output data, bit 3-0.
	.long cartWWFlashR			;@ 0xCE WonderWitch flash
	.long BankSwitch4_F_R		;@ 0xCF Alias to 0xC0

	.long BankSwitch1_R			;@ 0xD0 Alias to 0xC1
	.long BankSwitch1_H_R		;@ 0xD1 2 more bits for 0xC1
	.long BankSwitch2_R			;@ 0xD2 Alias to 0xC2
	.long BankSwitch2_H_R		;@ 0xD3 2 more bits for 0xC2
	.long BankSwitch3_R			;@ 0xD4 Alias to 0xC3
	.long BankSwitch3_H_R		;@ 0xD5 2 more bits for 0xC3
	.long karnakTimerR			;@ 0xD6 Programmable Interval Timer
	.long cartUnmR				;@ 0xD7
	.long karnakADPCMR			;@ 0xD8 ADPCM input
	.long karnakPCMR			;@ 0xD9 PCM output
	;@ 0xDA-0xDF
	.long cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR,cartUnmR
	;@ 0xE0-0xFF Is all cartUnmR

KarnakW:
	.long BankSwitch4_F_W		;@ 0xC0 Bank switch 0x40000-0xF0000
	.long BankSwitch1_W			;@ 0xC1 Bank switch 0x10000 (SRAM)
	.long BankSwitch2_W			;@ 0xC2 Bank switch 0x20000
	.long BankSwitch3_W			;@ 0xC3 Bank switch 0x30000
	.long cartUnmW				;@ 0xC4
	.long cartUnmW				;@ 0xC5
	.long cartUnmW				;@ 0xC6
	.long cartUnmW				;@ 0xC7
	.long cartUnmW				;@ 0xC8
	.long cartUnmW				;@ 0xC9
	.long cartUnmW				;@ 0xCA
	.long cartUnmW				;@ 0xCB
	.long cartGPIODirW			;@ 0xCC General purpose input/output direction, bit 3-0.
	.long cartGPIODataW			;@ 0xCD General purpose input/output data, bit 3-0.
	.long cartWWFlashW			;@ 0xCE WonderWitch flash
	.long BankSwitch4_F_W		;@ 0xCF Alias to 0xC0

	.long BankSwitch1_L_W		;@ 0xD0 Alias to 0xC1
	.long BankSwitch1_H_W		;@ 0xD1 2 more bits for 0xC1
	.long BankSwitch2_L_W		;@ 0xD2 Alias to 0xC2
	.long BankSwitch2_H_W		;@ 0xD3 2 more bits for 0xC2
	.long BankSwitch3_L_W		;@ 0xD4 Alias to 0xC3
	.long BankSwitch3_H_W		;@ 0xD5 2 more bits for 0xC3
	.long karnakTimerW			;@ 0xD6 Programmable Interval Timer
	.long cartUnmW				;@ 0xD7
	.long karnakADPCMW			;@ 0xD8 ADPCM input
	.long cartUnmW				;@ 0xD9 PCM output
	;@ 0xDA-0xDF
	.long cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW,cartUnmW
	;@ 0xE0-0xFF Is all cartUnmW

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .sbss				;@ For the GBA
#else
	.section .bss
#endif
	.align 2
cartSRAM:
#ifdef GBA
	.space 0x10000				;@ For the GBA
#else
	.space 0x40000
#endif
cartEepromMem:
	.space 0x800
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
