/*
 * SPI_DRIVER.h
 *
 *  Created on: Jan 29, 2024
 *      Author: Razi
 */

#ifndef SRC_SPI_DRIVER_H_
#define SRC_SPI_DRIVER_H_

extern uint32_t temp_data;

void SPI_TEST();
void vReverseBytes(void *pvDest, void *pvSrc, uint8_t unNumBytes);
void vMemCpy(void *pvDest, void *pvSrc, uint16_t udLength);
void SPI_BURST_TEST();

#endif /* SRC_SPI_DRIVER_H_ */
