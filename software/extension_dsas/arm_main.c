/*
 * ARM main.c — UDP-driven rollback path + FM AXI-Lite update + latency instrumentation
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "xparameters.h"
#include "platform.h"
#include "platform_config.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_types.h"
#include "xgpio.h"
#include "xscugic.h"
#include "xaxidma.h"
#include "sleep.h"

#include "lwip/init.h"
#include "lwip/inet.h"
#include "lwip/udp.h"
#include "lwip/tcp.h"
#include "netif/xadapter.h"

#if LWIP_DHCP==1
#include "lwip/dhcp.h"
extern volatile int dhcp_timoutcntr;
#endif

/* ============================================================= */
/* AXI / ADDR MAP */
/* ============================================================= */
#define LED_DELAY              10000000
#define ACTIVE_CHANNEL         1
#define IN_CHANNEL             2
#define TIME_DELAY             30

#define DMA_DEVICE_ID          XPAR_AXIDMA_0_DEVICE_ID
#define DMA_BASE_ADDR          0x10000000U

/* Shared mailbox in DDR visible to ARM + MicroBlaze (HP port) */
#define INTERACTION_ADDR       0x10001000U  

/* Mailbox field offsets for direct 32-bit writes (packed) */
#define MAILBOX_PINIT_OFFSET   0x18U  /* magic(0x00) cmd(0x04) status(0x08) err(0x0C)
                                         frame_len(0x10) dsas_cycle(0x14) pinit(0x18) */

/* Frame Manager (FM) AXI-Lite base + offsets */
#define FM_BASEADDR            0x44A10000U  
#define FM_REG_FRAME_LEN       0x00U        /* LFM */
#define FM_REG_FRAME_CNT       0x04U        /* optional RO */
#define FM_REG_STATUS          0x08U        /* optional RO */
#define FM_REG_CONTROL         0x0CU        /* CONTROL bits: [0]=enable [1]=manual_reinit [2]=force_tlast */

/* ============================================================= */
/* NETWORK CONFIG                                                */
/* ============================================================= */
#define DEFAULT_IP_ADDRESS     "192.168.1.10"
#define DEFAULT_IP_MASK        "255.255.255.0"
#define DEFAULT_GW_ADDRESS     "192.168.1.1"
#define UDP_LISTEN_PORT        54000        /* Host -> PS */
#define UDP_ACK_PORT           54001        /* PS -> Host ACK */

/* ============================================================= */
/* GLOBALS                                                       */
/* ============================================================= */
static XAxiDma AxiDma;
XGpio Gpio_0, Gpio_1;
struct netif server_netif;

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;

/* ============================================================= */
/* MAILBOX (ARM <-> MB) — unified struct                         */
/* ============================================================= */
typedef struct __attribute__((aligned(64))) {
  volatile uint32_t magic;                /* 'DSAS' = 0x44534153 */
  volatile uint32_t cmd;                  /* 1: FM_CONFIG, 2: ROLLBACK */
  volatile uint32_t status;               /* 0:IDLE, 1:BUSY, 2:DONE, 0xEE:ERR */
  volatile uint32_t err;

  volatile uint32_t frame_len;            /* LFM (transactions) */
  volatile uint32_t dsas_cycle;           /* n_dsas */
  volatile uint32_t pinit;                /* base pointer/offset */
  volatile uint32_t total_bytes;          /* optional payload bytes */

  volatile uint32_t t_arm_request_ms;     /* timestamps (ms) */
  volatile uint32_t t_mb_seen_ms;
  volatile uint32_t t_mb_cfg_done_ms;
  volatile uint32_t t_first_frame_done_ms;
  volatile uint32_t t_arm_done_ms;

  volatile uint32_t arm_req;              /* ARM->MB: 1 => new task */
  volatile uint32_t mb_done;              /* MB->ARM: 1 => finished */
  volatile uint32_t rsv[3];
} dsas_mailbox_t;

#define MAILBOX   ((volatile dsas_mailbox_t*)INTERACTION_ADDR)

/* ============================================================= */
/* Time helper (ms) */
/* ============================================================= */
static inline uint32_t get_time_ms(void) {
  /* crude stub using usleep(1000) granularity in callers */
  return (uint32_t) (xil_get_timer_counter() / (XPAR_CPU_CORTEXA9_0_CPU_CLK_FREQ_HZ/1000U));
}

/* ============================================================= */
/* lwIP helpers                                                  */
/* ============================================================= */
static void print_ip(char *msg, ip_addr_t *ip) {
  print(msg);
  xil_printf("%d.%d.%d.%d\r\n", ip4_addr1(ip), ip4_addr2(ip),
             ip4_addr3(ip), ip4_addr4(ip));
}
static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw) {
  print_ip("Board IP:       ", ip);
  print_ip("Netmask :       ", mask);
  print_ip("Gateway :       ", gw);
}
static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw) {
  int err;
  xil_printf("Configuring default IP %s \r\n", DEFAULT_IP_ADDRESS);
  err = inet_aton(DEFAULT_IP_ADDRESS, ip);
  if (!err) xil_printf("Invalid default IP address: %d\r\n", err);
  err = inet_aton(DEFAULT_IP_MASK, mask);
  if (!err) xil_printf("Invalid default IP MASK: %d\r\n", err);
  err = inet_aton(DEFAULT_GW_ADDRESS, gw);
  if (!err) xil_printf("Invalid default gateway address: %d\r\n", err);
}

/* ============================================================= */
/* UDP ACK helper                                                */
/* ============================================================= */
static struct udp_pcb *g_ack_pcb = NULL;
static ip_addr_t       g_last_sender_ip;
static u16_t           g_last_sender_port = 0;

static void udp_send_ack(const char *msg) {
  if (!g_ack_pcb || ip4_addr_isany_val(*ip_2_ip4(&g_last_sender_ip))) return;
  struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, (u16_t)strlen(msg), PBUF_RAM);
  if (!p) return;
  memcpy(p->payload, msg, strlen(msg));
  udp_sendto(g_ack_pcb, p, &g_last_sender_ip, UDP_ACK_PORT);
  pbuf_free(p);
}

/* Thin wrapper named per paper wording; reuses the existing ACK sender */
static void udp_data_transfer(const char *msg) {
  udp_send_ack(msg);
}

/* ============================================================= */
/* FM AXI-Lite write                                             */
/* ============================================================= */
static inline void fm_write_reg(uint32_t offset, uint32_t value) {
  Xil_Out32(FM_BASEADDR + offset, value);
}

/* Direct packed 32-bit write of pinit into the shared mailbox (per paper) */
static inline void write_pinit_via_xilout32(uint32_t pinit_val) {
  Xil_Out32(INTERACTION_ADDR + MAILBOX_PINIT_OFFSET, pinit_val);
}

/* ============================================================= */
/* Mapping from (debug_cycle, winLen, err_pos) -> (n_dsas, p_init)
   Eq.(4.8)/(4.9) mapping 
/* ============================================================= */
static void map_to_replay_params(int debug_cycle, int winLen, int err_pos,
                                 uint32_t *o_ndsas, uint32_t *o_pinit)
{
  /* TODO: precise derivation:
     ndsas = f(debug_cycle, winLen, err_pos)
     pinit = g(ndsas, ...) */
  uint32_t ndsas = (uint32_t)debug_cycle + (uint32_t)err_pos;
  uint32_t pinit = (uint32_t)(winLen * err_pos); /* example byte/word pointer */
  *o_ndsas = ndsas;
  *o_pinit = pinit;
}

/* ============================================================= */
/* ROLLBACK — per paper: update FM FRAME_LEN via AXI-Lite,
 * write mailbox (INTERACTION_ADDR), wait MB done, ACK Host
 * (5.3 State Restoration Mechanism Implementation)              */
/* ============================================================= */
static void rollback(int debug_cycle_in, int winLen_in, int err_pos_in)
{
  volatile dsas_mailbox_t* mbox = MAILBOX;

  uint32_t ndsas = 0, pinit = 0;
  map_to_replay_params(debug_cycle_in, winLen_in, err_pos_in, &ndsas, &pinit);

  /* 1) Update FM FRAME_LEN via AXI-Lite (runtime reconfig) */
  fm_write_reg(FM_REG_FRAME_LEN, (uint32_t)winLen_in);   /* FRAME_LEN = LFM */
  /* (Optional) when CONTROL[0]=enable=1 */
  /* uint32_t ctrl = 0x1; fm_write_reg(FM_REG_CONTROL, ctrl); */

  /* 2) Fill mailbox (shared DDR) */
  mbox->magic        = 0x44534153U;  /* 'DSAS' */
  mbox->cmd          = 2;            /* ROLLBACK */
  mbox->status       = 0;            /* IDLE */
  mbox->err          = 0;
  mbox->frame_len    = (uint32_t)winLen_in;
  mbox->dsas_cycle   = ndsas;
  mbox->pinit        = pinit;
  mbox->total_bytes  = (uint32_t)winLen_in * 4; /* if each transaction = 4B */

  /* Per paper: packed 32-bit write of pinit via Xil_Out32() into shared control address */
  write_pinit_via_xilout32(pinit);

  uint32_t t0_ms = (uint32_t)get_time_ms();
  mbox->t_arm_request_ms = t0_ms;
  mbox->mb_done      = 0;

  Xil_DCacheFlushRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));
  mbox->arm_req = 1;
  Xil_DCacheFlushRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));

  /* 3) Wait for MB to complete + gather timestamps */
  uint32_t t_done=0, t1_seen=0, t2_cfg=0, t3_ff=0;
  for (;;) {
    Xil_DCacheInvalidateRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));
    t1_seen = mbox->t_mb_seen_ms;
    t2_cfg  = mbox->t_mb_cfg_done_ms;
    t3_ff   = mbox->t_first_frame_done_ms;
    if (mbox->mb_done) {
      t_done = (uint32_t)get_time_ms();
      mbox->t_arm_done_ms = t_done;
      break;
    }
  }

  /* 4) Latency breakdown (ms) */
  uint32_t L_end2end = t_done - t0_ms;
  uint32_t L_arm     = (t1_seen >= t0_ms   ) ? (t1_seen - t0_ms)   : 0;
  uint32_t L_mb_cfg  = (t2_cfg  >= t1_seen ) ? (t2_cfg  - t1_seen) : 0;
  uint32_t L_replay  = (t3_ff   >= t2_cfg  ) ? (t3_ff   - t2_cfg)  : 0;

  xil_printf("[RB] winLen=%d err_pos=%d ndsas=%lu pinit=%lu\r\n",
             winLen_in, err_pos_in, (unsigned long)ndsas, (unsigned long)pinit);
  xil_printf("[RB] L_arm=%u ms, L_mb_cfg=%u ms, L_replay=%u ms, L_end2end=%u ms\r\n",
             L_arm, L_mb_cfg, L_replay, L_end2end);

  /* 5) ACK host */
  char ack_msg[96];
  snprintf(ack_msg, sizeof(ack_msg),
           "ACK ndsas=%lu pinit=%lu L=%u/%u/%u/%u",
           (unsigned long)ndsas, (unsigned long)pinit,
           L_arm, L_mb_cfg, L_replay, L_end2end);
  udp_send_ack(ack_msg);
  /* Per paper wording: acknowledgment via udp_data_transfer() */
  udp_data_transfer(ack_msg);
}

/* ============================================================= */
/* UDP receive callback: parse {debug_cycle, winLen, err_pos}
 * Payload format supported:
 *  - 12 raw bytes: 3 x uint32 (network order)
 *  - or ASCII: "debug_cycle,winLen,err_pos"
 * On success, calls rollback()                                     */
/* ============================================================= */
static void udp_recv_callback(void *arg, struct udp_pcb *upcb,
                              struct pbuf *p, const ip_addr_t *addr, u16_t port)
{
  g_last_sender_ip   = *addr;
  g_last_sender_port = port;

  uint32_t dbg=0, win=0, pos=0;
  int ok = 0;

  if (p && p->len >= 12) {
    /* try binary */
    uint8_t *b = (uint8_t*)p->payload;
    dbg = (b[0]<<24)|(b[1]<<16)|(b[2]<<8)|b[3];
    win = (b[4]<<24)|(b[5]<<16)|(b[6]<<8)|b[7];
    pos = (b[8]<<24)|(b[9]<<16)|(b[10]<<8)|b[11];
    ok = 1;
  } else if (p && p->len > 0) {
    /* try ASCII csv */
    char buf[128];
    int len = (p->len < (sizeof(buf)-1)) ? p->len : (sizeof(buf)-1);
    memcpy(buf, p->payload, len); buf[len] = 0;
    if (3 == sscanf(buf, "%u,%u,%u", &dbg, &win, &pos)) ok = 1;
  }

  if (ok) {
    xil_printf("[UDP] recv debug_cycle=%lu, winLen=%lu, err_pos=%lu\r\n",
               (unsigned long)dbg, (unsigned long)win, (unsigned long)pos);
    rollback((int)dbg, (int)win, (int)pos);
  } else {
    xil_printf("[UDP] invalid payload len=%d\r\n", (int)(p ? p->len : 0));
    udp_send_ack("ERR payload");
  }

  if (p) pbuf_free(p);
}

/* ============================================================= */
/* main()                                                        */
/* ============================================================= */
int main(void)
{
  int Status;
  volatile int Delay;
  volatile int time_delay_cnt = 0;
  XAxiDma_Config *DmaConfig;
  struct netif *netif = &server_netif;
  unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

  /* Platform init */
  init_platform();
  xil_printf("\r\n\r\n----- ARM lwIP + FM AXI-Lite + Rollback (UDP) -----\r\n");

  /* lwIP init */
  lwip_init();
  if (!xemac_add(netif, NULL, NULL, NULL, mac_ethernet_address, PLATFORM_EMAC_BASEADDR)) {
    xil_printf("Error adding N/W interface\r\n"); return -1;
  }
  netif_set_default(netif);
  platform_enable_interrupts();
  netif_set_up(netif);

  assign_default_ip(&(netif->ip_addr), &(netif->netmask), &(netif->gw));
  print_ip_settings(&(netif->ip_addr), &(netif->netmask), &(netif->gw));
  xil_printf("\r\n");

  /* UDP listener */
  struct udp_pcb *pcb = udp_new();
  if (!pcb) { xil_printf("udp_new failed\r\n"); return -1; }
  if (udp_bind(pcb, IP_ADDR_ANY, UDP_LISTEN_PORT) != ERR_OK) {
    xil_printf("udp_bind failed\r\n"); return -1;
  }
  udp_recv(pcb, udp_recv_callback, NULL);

  /* UDP ACK pcb */
  g_ack_pcb = udp_new();
  if (!g_ack_pcb) { xil_printf("udp_new ack failed\r\n"); return -1; }

  /* DMA init */
  XAxiDma_Config *cfgptr = NULL;
  cfgptr = XAxiDma_LookupConfig(DMA_DEVICE_ID);
  DmaConfig = cfgptr;
  Status = XAxiDma_CfgInitialize(&AxiDma, DmaConfig);
  if (Status != XST_SUCCESS) { xil_printf("DMA CfgInit failed %d\r\n", Status); return XST_FAILURE; }
  if (XAxiDma_HasSg(&AxiDma)) { xil_printf("DMA in SG mode (expect Simple)\r\n"); return XST_FAILURE; }
  Status = XAxiDma_Selftest(&AxiDma);
  if (Status != XST_SUCCESS) { xil_printf("XAxiDma_Selftest() failed! %d\r\n", Status); }
  XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
  XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

  /* GPIO init */
  Status = XGpio_Initialize(&Gpio_0, XPAR_AXI_GPIO_0_DEVICE_ID);
  if (Status != XST_SUCCESS) { xil_printf("GPIO0 init failed\r\n"); return XST_FAILURE; }
  Status = XGpio_Initialize(&Gpio_1, XPAR_AXI_GPIO_1_DEVICE_ID);
  if (Status != XST_SUCCESS) { xil_printf("GPIO1 init failed\r\n"); return XST_FAILURE; }
  XGpio_SetDataDirection(&Gpio_0, ACTIVE_CHANNEL, 0);
  XGpio_SetDataDirection(&Gpio_0, IN_CHANNEL, 1);
  XGpio_SetDataDirection(&Gpio_1, ACTIVE_CHANNEL, 0);

  /* Clear mailbox */
  volatile dsas_mailbox_t* mbox = MAILBOX;
  mbox->arm_req = 0; mbox->mb_done = 0; mbox->status = 0;
  Xil_DCacheFlushRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));

  /* Main loop */
  while (1) {
    if (TcpFastTmrFlag) { tcp_fasttmr(); TcpFastTmrFlag = 0; }
    if (TcpSlowTmrFlag) { tcp_slowtmr(); TcpSlowTmrFlag = 0; }
    xemacif_input(netif);

    /* Heartbeat LED */
    XGpio_DiscreteWrite(&Gpio_1, ACTIVE_CHANNEL, 1);
    for (Delay = 0; Delay < LED_DELAY; Delay++);
    XGpio_DiscreteClear(&Gpio_1, ACTIVE_CHANNEL, 1);
    for (Delay = 0; Delay < LED_DELAY; Delay++);

    time_delay_cnt++;
    if (time_delay_cnt == TIME_DELAY) {
      XGpio_DiscreteWrite(&Gpio_0, ACTIVE_CHANNEL, 1);
      time_delay_cnt = 0;
      xil_printf("HB: GPIO0 pulse\r\n");
      XGpio_DiscreteClear(&Gpio_0, ACTIVE_CHANNEL, 1);
    }
  }

  /* not reached */
  //cleanup_platform();
  //return 0;
}
