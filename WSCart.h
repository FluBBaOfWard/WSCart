#ifndef WSCART_HEADER
#define WSCART_HEADER

#ifdef __cplusplus
extern "C" {
#endif

#include "../WSEEPROM/WSEEPROM.h"
#include "WSHeader.h"

extern u32 gRomSize;
extern const int sramSize;
extern const int eepromSize;
extern WSEEPROM cartEeprom;
extern WsHeader *gGameHeader;
extern u8 gFileType;

extern u8 *romSpacePtr;
extern u8 cartSRAM[0x10000];
extern u8 cartEepromMem[0x800];

#ifdef __cplusplus
} // extern "C"
#endif

#endif // WSCART_HEADER
