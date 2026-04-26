#include "xil_printf.h"
#include "xgpio.h"
#include "xparameters.h"

#include <stdio.h>
//#include <xtmrctr.h>
#include "mb_interface.h"

#define MAX_COUNT 1000
#define BUFFER_SIZE 16

#define LED_DELAY 1000000
#define ACTIVE_CHANNEL 1

XGpio Gpio_2; /* The Instance of the GPIO Driver*/

/* Write 16 32-bit words as efficiently as possible */
static void inline write_axis(volatile unsigned int *a){
	register int a0,  a1,  a2,  a3;
	register int a4,  a5,  a6,  a7;
	register int a8,  a9,  a10, a11;
	register int a12, a13, a14, a15;

	a0 = a[0];    a1 = a[1];    a2 = a[2];    a3 = a[3];
	a4 = a[4];    a5 = a[5];    a6 = a[6];    a7 = a[7];
	a8 = a[8];    a9 = a[9];    a10 = a[10];  a11 = a[11];
	a12 = a[12];  a13 = a[13];  a14 = a[14];  a15 = a[15];

	nputfsl(a0,  0); nputfsl(a1,  0); nputfsl(a2,  0); nputfsl(a3,  0);
	nputfsl(a4,  0); nputfsl(a5,  0); nputfsl(a6,  0); nputfsl(a7,  0);
	nputfsl(a8,  0); nputfsl(a9,  0); nputfsl(a10, 0); nputfsl(a11, 0);
	nputfsl(a12, 0); nputfsl(a13, 0); nputfsl(a14, 0); ncputfsl(a15, 0);
}

/* Read 16 32-bit words as efficiently as possible */
static void inline read_axis(volatile unsigned int *a){
	register int a0,  a1,  a2,  a3;
	register int a4,  a5,  a6,  a7;
	register int a8,  a9,  a10, a11;
	register int a12, a13, a14, a15;

	ngetfsl(a0,  0); ngetfsl(a1,  0); ngetfsl(a2,  0); ngetfsl(a3,  0);
	ngetfsl(a4,  0); ngetfsl(a5,  0); ngetfsl(a6,  0); ngetfsl(a7,  0);
	ngetfsl(a8,  0); ngetfsl(a9,  0); ngetfsl(a10, 0); ngetfsl(a11, 0);
	ngetfsl(a12, 0); ngetfsl(a13, 0); ngetfsl(a14, 0); ncgetfsl(a15, 0);

	a[0] = a0;   a[1] = a1;     a[2] = a2;   a[3] = a3;
	a[4] = a4;   a[5] = a5;     a[6] = a6;   a[7] = a7;
	a[8] = a8;   a[9] = a9;     a[10] = a10; a[11] = a11;
	a[12] = a12; a[13] = a13;   a[14] = a14; a[15] = a15;
}

int main()
{
    //init_platform();

    //print("Hello World\n\r");
    //print("Successfully ran Hello World application\n\r");

    int Status, i;
    volatile int Delay;

    volatile unsigned int outbuffer[BUFFER_SIZE] = {
    		0x0,0x1,0x2,0x3,0x4,0x5,0x6,0x7,0x8,0x9,0xa,0xb,0xc,0xd,0xe,0xf
    };
    volatile unsigned int inbuffer[BUFFER_SIZE];
    //int count = 0;
    /* Initialize the GPIO 0 driver */
    /*Status = XGpio_Initialize(&Gpio_0,XPAR_AXI_GPIO_0_DEVICE_ID);
    if(Status != XST_SUCCESS){
    	xil_printf("GPIO 0 Initialization Failed\r\n");
    	return XST_FAILURE;
    }*/
    /* Initialize the GPIO 1 driver */
    /*Status = XGpio_Initialize(&Gpio_1,XPAR_AXI_GPIO_1_DEVICE_ID);
    if(Status != XST_SUCCESS){
    	xil_printf("GPIO 1 Initialization Failed\r\n");
        return XST_FAILURE;
    }*/
    /* Initialize the GPIO 2 driver */
    Status = XGpio_Initialize(&Gpio_2,XPAR_AXI_GPIO_2_DEVICE_ID);
    if(Status != XST_SUCCESS){
    	xil_printf("GPIO 2 Initialization Failed\r\n");
        return XST_FAILURE;
    }
    /* Set the direction for GPIO 0 as outputs */
    //XGpio_SetDataDirection(&Gpio_0,ACTIVE_CHANNEL,0);
    /* Set the direction for GPIO 1 as outputs */
    //XGpio_SetDataDirection(&Gpio_1,ACTIVE_CHANNEL,0);
    /* Set the direction for GPIO 1 as outputs */
    XGpio_SetDataDirection(&Gpio_2,ACTIVE_CHANNEL,0);
    /* GPIO LED blinks forever */
    while(1){
    	/* Set the LED to High */
    	//XGpio_DiscreteWrite(&Gpio_1,ACTIVE_CHANNEL,1);
    	XGpio_DiscreteClear(&Gpio_2,ACTIVE_CHANNEL,1);
    	/* Wait a small amount of time so the LED is visible */
    	for (Delay = 0; Delay < LED_DELAY; Delay++);
    	/* Clear the LED bit */
    	//XGpio_DiscreteClear(&Gpio_1,ACTIVE_CHANNEL,1);
    	XGpio_DiscreteWrite(&Gpio_2,ACTIVE_CHANNEL,1);
    	/* Wait a small amount of time so the LED is visible */
    	for (Delay = 0; Delay < LED_DELAY; Delay++);

    	/* perform transfers */
    	write_axis(outbuffer);
    	read_axis(inbuffer);

    	for (i=0; i<BUFFER_SIZE; i++){
    		outbuffer[i] = outbuffer[i] + 1;
    	}
    }

    //cleanup_platform();
    return 0;
}
