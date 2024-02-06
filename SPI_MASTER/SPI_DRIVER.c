/*
 * SPI_DRIVER.c
 *
 *  Created on: Jan 29, 2024
 *      Author: Razi
 */

#include <stdio.h>
#include <stdint.h>
#include "SPI_DRIVER.h"
#include "main.h"
#include "CRC8.h"
#include "string.h"

uint32_t spi_buff;
uint32_t temp_data = 1;
HAL_StatusTypeDef status;
uint8_t ulTXCrc = 0;
uint8_t ulRXCrc = 0;
uint8_t ulRXCrc_Calc = 0;
uint32_t SPI_BURST_DATA[10];

uint8_t unSPISendPktBuff[5];
uint8_t unSPIRecvPktBuff[5];

void SS_LOW();
void SS_HIGH();
void SPI_SEND_DATA(uint8_t* data, uint8_t bytes);
void SPI_RECIEVE_DATA(uint8_t* recv_buff, uint8_t bytes);
void vReverseBytes(void *pvDest, void *pvSrc, uint8_t unNumBytes);
void vMemCpy(void *pvDest, void *pvSrc, uint16_t udLength);
void SPI_BURST_TEST();


void SPI_TEST()
{
	static uint8_t tx = 0;
	if(tx == 0)
	{
		SPI_SEND_DATA((uint8_t *)&temp_data,4);
		tx = 1;
		temp_data++;
		if(temp_data > 10)
			temp_data = 1;
	}
	if(HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_5))
	{
		SPI_RECIEVE_DATA((uint8_t *)&spi_buff,4);
		tx = 0;
	}
}

void SPI_BURST_TEST()
{
	static uint8_t tx = 0;
	uint32_t burst_cmd = 11;
	uint8_t burst_count = 0;
	if(tx == 0)
	{
		SPI_SEND_DATA((uint8_t *)&burst_cmd,4);
		tx = 1;
	}
	while(burst_count < 10)
	{
		if(HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_5))
		{
			SPI_RECIEVE_DATA((uint8_t *)&SPI_BURST_DATA[burst_count],4);
			burst_count++;

		}
	}
	burst_count = 0;
	tx = 0;

}

void SPI_SEND_DATA(uint8_t* data, uint8_t bytes)
{
	uint8_t udPktSize = 0;
	uint32_t TX_data;

	vReverseBytes((uint8_t *)&TX_data,data,bytes);

	crc8_start(1);
	crc8_update((uint8_t *)&TX_data, bytes);
	ulTXCrc = crc8_finish();

	memcpy(&unSPISendPktBuff[udPktSize],(uint8_t *)&TX_data,bytes);
	udPktSize += bytes;

	memcpy(&unSPISendPktBuff[udPktSize],&ulTXCrc,sizeof(ulTXCrc));
	udPktSize += sizeof(ulTXCrc);

	SS_LOW();
	status = HAL_SPI_Transmit(&hspi1, unSPISendPktBuff, udPktSize, 100);
	SS_HIGH();
}

void SPI_RECIEVE_DATA(uint8_t* recv_buff, uint8_t bytes)
{
	SS_LOW();
	status = HAL_SPI_Receive(&hspi1, unSPIRecvPktBuff, bytes+1, 100);
	SS_HIGH();

	memcpy(&ulRXCrc,&unSPIRecvPktBuff[bytes],sizeof(ulRXCrc));
	crc8_start(1);
	crc8_update(unSPIRecvPktBuff, bytes);
	ulRXCrc_Calc = crc8_finish();
	if(ulRXCrc_Calc == ulRXCrc)
	{
		vReverseBytes(recv_buff,unSPIRecvPktBuff,bytes);
	}
}

void SS_LOW()
{
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_7, GPIO_PIN_RESET);
}

void SS_HIGH()
{
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_7, GPIO_PIN_SET);
}

void vReverseBytes(void *pvDest, void *pvSrc, uint8_t unNumBytes)
{
	uint8_t *punDest = (uint8_t *)pvDest;
	uint8_t *punSrc = (uint8_t *)pvSrc;
	if (unNumBytes > 1)
	{
		punSrc += unNumBytes;
		while (unNumBytes-- > 0)
		{
			*punDest++ = *(--punSrc);
		}
	}
	else
	{
		vMemCpy(punDest, punSrc, unNumBytes);
	}
}

void vMemCpy(void *pvDest, void *pvSrc, uint16_t udLength)
{
	char *pchSrc = (char *)pvSrc;
	char *pchDest = (char *)pvDest;
	int i;
	for (i = 0; i < udLength; i++)
	{
		pchDest[i] = pchSrc[i];
	}
}
