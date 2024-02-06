
#ifndef SRC_CRC8_H_
#define SRC_CRC8_H_

//==============================================================================
//                        INCLUDE FILES
//==============================================================================
#include "stdint.h"
//==============================================================================
//                      EXTERNAL FUNCTIONS
//==============================================================================
void vCalculateCRC(uint8_t *data, uint8_t len, uint8_t *m_crc);
void crc8_start(int type);
void crc8_update(uint8_t *data,uint8_t len);
uint8_t crc8_finish(void);
//==============================================================================
//                       End   Of   File
//==============================================================================

#endif /* SRC_CRC8_H_ */
