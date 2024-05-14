#include <stdint.h>
#include "tm4c123gh6pm.h"
#include "emp_type.h"
#include "tmodel.h"
#include "FreeRTOS.h"
#include "queue.h"
#include "semphr.h"
#include "task.h"
#include "userSwitch.h"
#include "keypad.h"


extern QueueHandle_t xQueue_keypad;
extern SemaphoreHandle_t xSemaphore_keypad;


extern QueueHandle_t xQueue_SPI;
extern SemaphoreHandle_t xSemaphore_SPI;


void SSI2_Init(void) {
    int dummy;


    //SYSCTL_RCC_R |= (0x2<<4);
    SYSCTL_RCGCSSI_R |= (1<<2);
    SYSCTL_RCGCGPIO_R |= (1<<1);

    dummy = SYSCTL_RCGCSSI_R;
    dummy = SYSCTL_RCGCGPIO_R;

    GPIO_PORTB_AMSEL_R &= ~0xf0;

    GPIO_PORTB_AFSEL_R |= 0b11110000;


    GPIO_PORTB_PCTL_R |= (2<<16) | (2<<20) | (2<<24) | (2<<28);

    GPIO_PORTB_DEN_R |= (1<<4) | (1<<5) | (1<<6) | (1<<7);

    GPIO_PORTB_DIR_R |= 0b10110000;


    SSI2_CR1_R = 0x00000000;

    SSI2_CC_R = 0x00;

    SSI2_CPSR_R = 2;

    SSI2_CR0_R = 0x0000f;

    SSI2_CR1_R |= 2;

    //GPIO_PORTB_DATA_R |= (1<<5); //SS/CS high, idle

    //GPIO_PORTB_DATA_R &= ~(1<<5); //SS/CS low, for transmission


}




void SSI2_Transfer(INT16U data) {

        while((SSI2_SR_R & 2) == 0); // Bit 1 is the TNF (Transmit FIFO Not Full) flag
        SSI2_DR_R = data;

}




void SPI_task(void *pvParameters)
{
    SSI2_Init();

    static INT8U keyPressed;
    static INT8U key;
    static INT16U data;
    static INT16U dataToSend;
    while(1)
    {
        if (uxQueueMessagesWaiting(xQueue_keypad))
        {
            if (xSemaphoreTake(xSemaphore_keypad, portMAX_DELAY))
            {
                if (xQueueReceive(xQueue_keypad, &key, portMAX_DELAY))
                {
                    keyPressed = key;
                    //GPIO_PORTF_DATA_R ^= 0x02;
                    xSemaphoreGive(xSemaphore_keypad);

                    if (keyPressed == 0x31)
                    {
                        data = 0x0001;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x32)
                    {

                        data = 0x0002;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x33)
                    {

                        data = 0x0003;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x34)
                    {

                        data = 0x0004;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x35)
                    {

                        data = 0x0005;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x36)
                    {

                        data = 0x0006;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x37)
                    {

                        data = 0x0007;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x38)
                    {

                        data = 0x0008;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x39)
                    {

                        data = 0x0009;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x2A)
                    {

                        data = 0x0010;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x30)
                    {

                        data = 0x0011;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                    if (keyPressed == 0x23)
                    {

                        data = 0x0012;
                        if (uxQueueSpacesAvailable(xQueue_SPI))
                        {
                            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
                            {
                                if (xQueueSend(xQueue_SPI, &data, portMAX_DELAY))
                                {

                                    xSemaphoreGive(xSemaphore_SPI);

                                }
                            }
                        }
                        keyPressed = 0x00;
                    }

                }
            }
        }

        if (uxQueueMessagesWaiting(xQueue_SPI))
        {
            if (xSemaphoreTake(xSemaphore_SPI, portMAX_DELAY))
            {
                if (xQueueReceive(xQueue_SPI, &dataToSend, portMAX_DELAY))
                {
                    SSI2_Transfer(dataToSend);
                    xSemaphoreGive(xSemaphore_SPI);
                }
            }
        }
    }
}
