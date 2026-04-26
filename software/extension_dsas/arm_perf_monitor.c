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

// === ASIC NOTE: time source for end-to-end measurement ===
#include "xtime_l.h"    // XTime_GetTime()

#define LED_DELAY       10000000
#define ACTIVE_CHANNEL  1
#define IN_CHANNEL      2
#define TIME_DELAY      30

#define INTC_DEVICE_ID        XPAR_SCUGIC_0_DEVICE_ID
#define INTC_DEVICE_INT_ID    62U

#define DMA_DEVICE_ID         XPAR_AXIDMA_0_DEVICE_ID
#define DMA_BASE_ADDR         0x10000000

#define MAX_PKT_LEN           4096

// ==================== PERF MON (AXI-Lite) ====================
// ASIC NOTE: keep current mapping; Address Editor provides base.
#define PERF_BASE      0x40000000U
#define REG_CTRL       0x00   // W: bit0=CLR, bit1=START, bit2=STOP (one-shot)
#define REG_ACTIVE     0x04   // R: bit0=active
#define REG_BEATS_IN   0x10   // R
#define REG_BEATS_OUT  0x14   // R
#define REG_STALL_UP   0x18   // R
#define REG_STALL_DN   0x1C   // R
#define REG_CYCLES     0x20   // R

#define WR32(o, v)  Xil_Out32((PERF_BASE + (o)), (u32)(v))
#define RD32(o)     Xil_In32 (PERF_BASE + (o))

// === ASIC NOTE: one-shot control helpers ===
static inline void perf_clear(void) { WR32(REG_CTRL, 0x1); }
static inline void perf_start(void) { WR32(REG_CTRL, 0x2); }
static inline void perf_stop (void) { WR32(REG_CTRL, 0x4); }

// === ASIC NOTE: convert CPU ticks to microseconds (integer) ===
static inline u32 ticks_to_us_u32(u64 dt_ticks)
{
#ifdef COUNTS_PER_SECOND
    return (u32)((dt_ticks * 1000000ULL) / (u64)COUNTS_PER_SECOND);
#else
    // Fallback if BSP misses COUNTS_PER_SECOND; adjust if needed.
    const u64 gt_freq_hz = 333000000ULL;
    return (u32)((dt_ticks * 1000000ULL) / gt_freq_hz);
#endif
}

XGpio Gpio_0, Gpio_1;
static XAxiDma AxiDma;
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

    // === DMA INIT ===
    DmaConfig = XAxiDma_LookupConfig(DMA_DEVICE_ID);
    Status = XAxiDma_CfgInitialize(&AxiDma, DmaConfig);
    if (Status != XST_SUCCESS) {
        xil_printf("Initialization failed %d\r\n", Status);
        return XST_FAILURE;
    }
    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("Device configured as SG mode\r\n");
        return XST_FAILURE;
    }
    Status = XAxiDma_Selftest(&AxiDma);
    if (Status != XST_SUCCESS) {
        xil_printf("XAxiDma_Selftest() failed! Status=%d\r\n", Status);
    }

    // === IRQ MASK ===
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    // === GPIO INIT ===
    Status = XGpio_Initialize(&Gpio_0, XPAR_AXI_GPIO_0_DEVICE_ID);
    if (Status != XST_SUCCESS) {
        xil_printf("GPIO 0 Initialization Failed\r\n");
        return XST_FAILURE;
    }
    Status = XGpio_Initialize(&Gpio_1, XPAR_AXI_GPIO_1_DEVICE_ID);
    if (Status != XST_SUCCESS) {
        xil_printf("GPIO 1 Initialization Failed\r\n");
        return XST_FAILURE;
    }

    // === GPIO DIR ===
    XGpio_SetDataDirection(&Gpio_0, ACTIVE_CHANNEL, 0);
    XGpio_SetDataDirection(&Gpio_0, IN_CHANNEL,     1);
    XGpio_SetDataDirection(&Gpio_1, ACTIVE_CHANNEL, 0);

    // === MAIN LOOP ===
    while (1) {

        if (XGpio_DiscreteRead(&Gpio_0, IN_CHANNEL)) {
            xil_printf("FIFO is full!\r\n");

            // ASIC NOTE: invalidate RX window before DMA
            Xil_DCacheInvalidateRange((UINTPTR)RxBufferPtr, MAX_PKT_LEN);

            // === PERF START ===
            perf_clear();
            perf_start();

            XTime t0, t1;
            XTime_GetTime(&t0);

            // S2MM only (capture from PL to DDR)
            Status = XAxiDma_SimpleTransfer(&AxiDma,
                                            (UINTPTR)RxBufferPtr,
                                            MAX_PKT_LEN,
                                            XAXIDMA_DEVICE_TO_DMA);
            if (Status != XST_SUCCESS) {
                xil_printf("DMA Transfer Failed!\r\n");
            } else {

                while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA));

                XTime_GetTime(&t1);
                perf_stop();

                // ASIC NOTE: make RX visible for CPU
                Xil_DCacheInvalidateRange((UINTPTR)RxBufferPtr, MAX_PKT_LEN);

                // === READ PERF REGISTERS (all 32-bit) ===
                u32 bin   = RD32(REG_BEATS_IN);
                u32 bout  = RD32(REG_BEATS_OUT);
                u32 sup   = RD32(REG_STALL_UP);
                u32 sdn   = RD32(REG_STALL_DN);
                u32 cyc   = RD32(REG_CYCLES);

                // === TIME IN MICROSECONDS (INTEGER) ===
                u64 dt_ticks = (u64)(t1 - t0);
                u32 us       = ticks_to_us_u32(dt_ticks);

                // === THROUGHPUT (INTEGER / FIXED-POINT) ===
                // thr_sps = samples/sec = bout * 1e6 / us
                u32 thr_sps  = (us ? (u32)(((u64)bout * 1000000ULL) / us) : 0);
                // MB/s with one decimal: MBps_x10 = (bout*4 bytes)*10 / us
                u32 mbps_x10 = (us ? (u32)(((u64)bout * 4ULL * 10ULL) / us) : 0);

                // === BACKPRESSURE (PERMILLE) ===
                u32 up_pm = (cyc ? (u32)(((u64)sup * 1000ULL) / cyc) : 0);
                u32 dn_pm = (cyc ? (u32)(((u64)sdn * 1000ULL) / cyc) : 0);

                // === ASIC-STYLE LOG (ALL INTEGERS, xil_printf-SAFE) ===
                xil_printf("[MEAS] us=%u  thr_sps=%u  MBps=%u.%u  "
                           "stall_up=%u(‰)  stall_dn=%u(‰)\r\n",
                           us, thr_sps, (mbps_x10 / 10), (mbps_x10 % 10),
                           up_pm, dn_pm);


                xil_printf("DMA Done! Dump first %d bytes:\r\n", MAX_PKT_LEN);
                for (i = 0; i < MAX_PKT_LEN/4; i++) {
                    rev = Xil_In32(DMA_BASE_ADDR + i*4);
                    xil_printf("Addr: %08x, Value: %08x \r\n",
                               DMA_BASE_ADDR + i*4, rev);
                }
            }
        }

        // === GPIO HEARTBEAT ===
        XGpio_DiscreteWrite(&Gpio_1, ACTIVE_CHANNEL, 1);
        for (Delay = 0; Delay < LED_DELAY; Delay++);
        XGpio_DiscreteClear(&Gpio_1, ACTIVE_CHANNEL, 1);
        for (Delay = 0; Delay < LED_DELAY; Delay++);

        // === PERIODIC PULSE ON GPIO_0 ===
        time_delay_cnt++;
        if (time_delay_cnt == TIME_DELAY) {
            XGpio_DiscreteWrite(&Gpio_0, ACTIVE_CHANNEL, 1);
            time_delay_cnt = 0;
            xil_printf("GPIO 0 pulled high\r\n");
            XGpio_DiscreteClear(&Gpio_0, ACTIVE_CHANNEL, 1);
        }
    }
    //cleanup_platform();
    return 0;
}
