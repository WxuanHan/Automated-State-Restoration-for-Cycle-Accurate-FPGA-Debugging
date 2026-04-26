#include <stdio.h>
#include <stdlib.h>
//#include "platform.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xil_exception.h"
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_types.h"
#include "xscugic.h"
#include "xaxidma.h"
#include "xdebug.h"

#define LED_DELAY 10000000
#define ACTIVE_CHANNEL 1
#define IN_CHANNEL 2

#define TIME_DELAY 30

#define INTC_DEVICE_ID XPAR_SCUGIC_0_DEVICE_ID
#define INTC_DEVICE_INT_ID 62U

#define DMA_DEVICE_ID XPAR_AXIDMA_0_DEVICE_ID
#define DMA_BASE_ADDR 0x10000000

#define MAX_PKT_LEN 4096

/************ Function Prototypes ***********************/
//int ScuGicFifo(u16 DeviceId);
//int SetUpInterruptSystem(XScuGic *XScuGicInstancePtr);
//void DeviceDriverHandler(void *CallbackRef);

//XScuGic InterruptController;
//static XScuGic_Config *GicConfig;

//volatile static int InterruptProcessed = FALSE;

//static void AssertPrint(const char8 *FilenamePtr, s32 LineNumber){
//	xil_printf("ASSERT: File Name: %s ", FilenamePtr);
//	xil_printf("Line Number: %d\r\n", LineNumber);
//}

XGpio Gpio_0, Gpio_1; /* The Instance of the GPIO Driver*/

static XAxiDma AxiDma;
//#define _countof(arr) (sizeof(arr) / sizeof(*(arr)))

static u8 *RxBufferPtr = (u8 *) DMA_BASE_ADDR;

int main()
{
    //init_platform();

    print("Hello World\n\r");
    print("Successfully ran Hello World application\n\r");

    int Status;
	int i;
	int rev;
    volatile int Delay;
    volatile int time_delay_cnt = 0;

    XAxiDma_Config *DmaConfig;

    /* Initialize the DMA driver */
    DmaConfig = XAxiDma_LookupConfig(DMA_DEVICE_ID);
    Status = XAxiDma_CfgInitialize(&AxiDma, DmaConfig);
    if (Status != XST_SUCCESS) {
    	xil_printf("Initialization failed %d\r\n", Status);
    	return XST_FAILURE;
    }
	if(XAxiDma_HasSg(&AxiDma)){
		xil_printf("Device configured as SG mode\n\r");
		return XST_FAILURE;
	}
	Status = XAxiDma_Selftest(&AxiDma);
    if(Status != XST_SUCCESS){
        printf("XAxiDma_Selftest() failed! Status=%d\n\r", Status);
    }
	/* Disable all interrupts before setup */

	XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK,
						XAXIDMA_DMA_TO_DEVICE);

	XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK,
				XAXIDMA_DEVICE_TO_DMA);

	/* Enable all interrupts */
	//XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_ALL_MASK,
	//						XAXIDMA_DMA_TO_DEVICE);


	//XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_ALL_MASK,
	//						XAXIDMA_DEVICE_TO_DMA);
    /* Initialize the GPIO 0 driver */
    Status = XGpio_Initialize(&Gpio_0,XPAR_AXI_GPIO_0_DEVICE_ID);
    if(Status != XST_SUCCESS){
    	xil_printf("GPIO 0 Initialization Failed\n\r");
    	return XST_FAILURE;
    }
    /* Initialize the GPIO 1 driver */
    Status = XGpio_Initialize(&Gpio_1,XPAR_AXI_GPIO_1_DEVICE_ID);
    if(Status != XST_SUCCESS){
    	xil_printf("GPIO 1 Initialization Failed\n\r");
        return XST_FAILURE;
    }
    /* Initialize DMA driver */
    /* Initialize the GPIO 2 driver */
    //Status = XGpio_Initialize(&Gpio_2,XPAR_AXI_GPIO_2_DEVICE_ID);
    //if(Status != XST_SUCCESS){
    //	xil_printf("GPIO 2 Initialization Failed\r\n");
    //    return XST_FAILURE;
    //}
    /* Set the direction for GPIO 0 as outputs */
    XGpio_SetDataDirection(&Gpio_0,ACTIVE_CHANNEL,0);
    XGpio_SetDataDirection(&Gpio_0,IN_CHANNEL,1);
    /* Set the direction for GPIO 1 as outputs */
    XGpio_SetDataDirection(&Gpio_1,ACTIVE_CHANNEL,0);
    /* Set the direction for GPIO 1 as outputs */
    //XGpio_SetDataDirection(&Gpio_2,ACTIVE_CHANNEL,0);

    // Interrupt occurs, when FIFO is full
    // ScuGicFifo(INTC_DEVICE_INT_ID);

    /* GPIO LED blinks forever */
    while(1){
    	/* Set the LED to High */
    	if(XGpio_DiscreteRead(&Gpio_0,IN_CHANNEL)){
    		xil_printf("FIFO is full!\r\n");
    		Status = XAxiDma_Selftest(&AxiDma);
    		if(Status != XST_SUCCESS){
    		    printf("XAxiDma_Selftest() failed! Status=%d\n\r", Status);
    		}
    		Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, MAX_PKT_LEN);
    		Status = XAxiDma_SimpleTransfer(&AxiDma,(UINTPTR) RxBufferPtr,
    							MAX_PKT_LEN, XAXIDMA_DEVICE_TO_DMA);
    		if(Status != XST_SUCCESS){
    			xil_printf("DMA Transfer Failed!\r\n");
    		}
    		else{
    			xil_printf("DMA Done!\r\n");
        		for(i=0; i<MAX_PKT_LEN/4;i++){
        			rev = Xil_In32(DMA_BASE_ADDR + i*4);
        			xil_printf("Addr: %08x, Value: %08x \r\n", DMA_BASE_ADDR + i*4, rev);
        		}
    		}
    	}
    	XGpio_DiscreteWrite(&Gpio_1,ACTIVE_CHANNEL,1);
    	//XGpio_DiscreteClear(&Gpio_2,ACTIVE_CHANNEL,1);
    	/* Wait a small amount of time so the LED is visible */
    	for (Delay = 0; Delay < LED_DELAY; Delay++);
    	/* Clear the LED bit */
    	XGpio_DiscreteClear(&Gpio_1,ACTIVE_CHANNEL,1);
    	//XGpio_DiscreteWrite(&Gpio_2,ACTIVE_CHANNEL,1);
    	/* Wait a small amount of time so the LED is visible */
    	for (Delay = 0; Delay < LED_DELAY; Delay++);

    	time_delay_cnt++;
    	if(time_delay_cnt == TIME_DELAY){
    		XGpio_DiscreteWrite(&Gpio_0,ACTIVE_CHANNEL,1);
    		time_delay_cnt = 0;
    		xil_printf("GPIO 0 pulled high\r\n");
    		XGpio_DiscreteClear(&Gpio_0,ACTIVE_CHANNEL,1);
    	}
    }
    //cleanup_platform();
    return 0;
}

/*
int ScuGicFifo(u16 DeviceId){
	int Status;
	GicConfig = XScuGic_LookupConfig(DeviceId);
	if(NULL == GicConfig){
		return XST_FAILURE;
	}

	Status = XScuGic_CfgInitialize(&InterruptController, GicConfig, GicConfig->CpuBaseAddress);
	if(Status != XST_SUCCESS){
		return XST_FAILURE;
	}

	Status = XScuGic_SelfTest(&InterruptController);
	if(Status != XST_SUCCESS){
		return XST_FAILURE;
	}

	Status = SetUpInterruptSystem(&InterruptController);
	if(Status != XST_SUCCESS){
		return XST_FAILURE;
	}

	Status = XScuGic_Connect(&InterruptController, INTC_DEVICE_INT_ID,
			(Xil_ExceptionHandler)DeviceDriverHandler, (void *)&InterruptController);
	if(Status != XST_SUCCESS){
		return XST_FAILURE;
	}

	XScuGic_Enable(&InterruptController, INTC_DEVICE_INT_ID);

	return XST_SUCCESS;
}

int SetUpInterruptSystem(XScuGic *XScuGicInstancePtr){
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler,
			XScuGicInstancePtr);
	Xil_ExceptionEnable();
	return XST_SUCCESS;
}

void DeviceDriverHandler(void *CallbackRef){
	int Status;
	int i;
	int rev;
	xil_printf("Interrupt Happens!/r/n");
	Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, MAX_PKT_LEN);
	Status = XAxiDma_SimpleTransfer(&AxiDma,(UINTPTR) RxBufferPtr,
						MAX_PKT_LEN, XAXIDMA_DEVICE_TO_DMA);
	if(Status != XST_SUCCESS){
		xil_printf("DMA Transfer Failed!/r/n");
	}
	xil_printf("DMA Done!/r/n");
	for(i=0; i<MAX_PKT_LEN/4;i++){
		rev = Xil_In32(DMA_BASE_ADDR + i*4);
		xil_printf("Addr: %d, Value: %04 /r/n", DMA_BASE_ADDR + i*4, rev);
	}
}
*/
