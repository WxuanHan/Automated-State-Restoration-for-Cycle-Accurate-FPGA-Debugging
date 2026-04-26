`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/02 18:32:55
// Design Name: 
// Module Name: frame_manager
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// /*
 * MicroBlaze mb_main.c — Poll mailbox & drive FM per paper rollback flow
 */

#include <stdio.h>
#include <string.h>
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xil_cache.h"
#include "sleep.h"

/* ============================================================= */
/* Address map */
/* ============================================================= */

/* Shared mailbox in DDR, visible to ARM + MicroBlaze (HP port) */
#define INTERACTION_ADDR       0x10001000U   

/* Frame Manager (FM) AXI-Lite base + offsets */
#define FM_BASEADDR            0x44A10000U   
#define FM_REG_FRAME_LEN       0x00U
#define FM_REG_FRAME_CNT       0x04U
#define FM_REG_STATUS          0x08U
#define FM_REG_CONTROL         0x0CU
#define FM_REG_TRANS_NUM       0x10U
#define FM_REG_DSAS_CYC        0x14U
#define FM_REG_DMA_LENB        0x18U

/* CONTROL bits */
#define FM_CONTROL_ENABLE_BIT        (1u << 0)  /* enable streaming */
#define FM_CONTROL_MANUAL_REINIT_BIT (1u << 1)  /* one-shot reinit */
#define FM_CONTROL_FORCE_TLAST_BIT   (1u << 2)  /* optional */

/* STATUS bits */
#define FM_STATUS_FIFO_EMPTY_BIT     (1u << 0)
#define FM_STATUS_DMA_BUSY_BIT       (1u << 1)
#define FM_STATUS_EOF_PULSE_BIT      (1u << 2)

/* ============================================================= */
/* Unified mailbox struct */
/* ============================================================= */
typedef struct __attribute__((aligned(64))) {
  volatile uint32_t magic;                /* 'DSAS' = 0x44534153 */
  volatile uint32_t cmd;                  /* 1: FM_CONFIG, 2: ROLLBACK */
  volatile uint32_t status;               /* 0:IDLE, 1:BUSY, 2:DONE, 0xEE:ERR */
  volatile uint32_t err;

  volatile uint32_t frame_len;            /* LFM (transactions) */
  volatile uint32_t dsas_cycle;           /* n_dsas (for correlation) */
  volatile uint32_t pinit;                /* base pointer/offset (Eq.4.9) */
  volatile uint32_t total_bytes;          /* optional */

  volatile uint32_t t_arm_request_ms;     /* timestamps */
  volatile uint32_t t_mb_seen_ms;
  volatile uint32_t t_mb_cfg_done_ms;
  volatile uint32_t t_first_frame_done_ms;
  volatile uint32_t t_arm_done_ms;

  volatile uint32_t arm_req;              /* ARM->MB */
  volatile uint32_t mb_done;              /* MB->ARM */
  volatile uint32_t rsv[3];
} dsas_mailbox_t;

#define MAILBOX   ((volatile dsas_mailbox_t*)INTERACTION_ADDR)

/* ============================================================= */
/* Minimal time helper (ms) */                                
/* ============================================================= */
static inline uint32_t get_time_ms(void) {
  /* Portable stub: returns a monotonic counter in ms-ish steps /
  static uint32_t ms = 0;
  return ++ms;
}

/* ============================================================= */
/* FM AXI-Lite helpers                                            */
/* ============================================================= */
static inline void fm_write_reg(uint32_t offset, uint32_t value) {
  Xil_Out32(FM_BASEADDR + offset, value);
}
static inline uint32_t fm_read_reg(uint32_t offset) {
  return Xil_In32(FM_BASEADDR + offset);
}


static void do_hw_reinit_and_arm(uint32_t frame_len, uint32_t dsas_cycle, uint32_t pinit)
{
  (void)dsas_cycle;
  (void)pinit;  /* Keep for future extension */

  /* Program FRAME_LEN first (affects DMA burst length in FM) */
  fm_write_reg(FM_REG_FRAME_LEN, frame_len);

  /* Enable + manual reinit (one-shot) */
  uint32_t ctrl = 0;
  ctrl |= FM_CONTROL_ENABLE_BIT;
  ctrl |= FM_CONTROL_MANUAL_REINIT_BIT;
  fm_write_reg(FM_REG_CONTROL, ctrl);

  /* If MANUAL_REINIT needs explicit clear, uncomment:
     ctrl &= ~FM_CONTROL_MANUAL_REINIT_BIT;
     fm_write_reg(FM_REG_CONTROL, ctrl);
  */

  /* (Optional) assert FORCE_TLAST for a single boundary:
     // ctrl |= FM_CONTROL_FORCE_TLAST_BIT;
     // fm_write_reg(FM_REG_CONTROL, ctrl);
  */
}

/* ============================================================= */
/* Handle one ARM request                                        */
/* ============================================================= */
static void handle_arm_request(volatile dsas_mailbox_t* mbox)
{
  /* Basic validation */
  if (mbox->magic != 0x44534153U) {
    mbox->status = 0xEE;   /* ERR */
    mbox->err    = 1;
    return;
  }

  /* Acknowledge and mark busy */
  mbox->status = 1; /* BUSY */
  mbox->t_mb_seen_ms = get_time_ms();

  /* Read parameters (ARM should have flushed cache) */
  uint32_t frame_len  = mbox->frame_len;
  uint32_t ndsas      = mbox->dsas_cycle;
  uint32_t pinit      = mbox->pinit;

  xil_printf("[MB] Req cmd=%lu LFM=%lu ndsas=%lu pinit=%lu\r\n",
             (unsigned long)mbox->cmd,
             (unsigned long)frame_len,
             (unsigned long)ndsas,
             (unsigned long)pinit);

  /* Optional: Invalidate cache lines for mailbox (if MB has dcache) */
  Xil_DCacheInvalidateRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));

  /* Configure FM and (optionally) other HW paths */
  do_hw_reinit_and_arm(frame_len, ndsas, pinit);

  /* Mark cfg done */
  mbox->t_mb_cfg_done_ms = get_time_ms();

  /* Wait first frame completion: poll FRAME_CNT increases */
  uint32_t cnt0 = fm_read_reg(FM_REG_FRAME_CNT);
  uint32_t guard = 0;
  while (guard < 1000000U) { /* simple guard to avoid hard lock */
    uint32_t cnt  = fm_read_reg(FM_REG_FRAME_CNT);
    if (cnt != cnt0) {
      mbox->t_first_frame_done_ms = get_time_ms();
      break;
    }
    guard++;
  }

  /* Mark done and handshake back */
  mbox->mb_done = 1;
  mbox->status  = 2; /* DONE */

  /* Clear arm_req so ARM knows we consumed it */
  mbox->arm_req = 0;

  /* Flush mailbox so ARM sees updates immediately */
  Xil_DCacheFlushRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));
}

/* ============================================================= */
/* main() — polling loop                                         */
/* ============================================================= */
int main(void)
{
  xil_printf("\r\n\r\n----- MicroBlaze Rollback Agent (Mailbox + FM) -----\r\n");

  volatile dsas_mailbox_t* mbox = MAILBOX;

  /* Initialize mailbox to a known state */
  mbox->mb_done = 0;
  mbox->status  = 0;  /* IDLE */
  mbox->err     = 0;
  Xil_DCacheFlushRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));

  /* Optionally enable FM globally at boot */
  uint32_t ctrl = FM_CONTROL_ENABLE_BIT;
  fm_write_reg(FM_REG_CONTROL, ctrl);

  while (1) {
    /* Poll mailbox for request */
    Xil_DCacheInvalidateRange((UINTPTR)mbox, sizeof(dsas_mailbox_t));
    if (mbox->arm_req) {
      handle_arm_request(mbox);
    }

    /* Small sleep to reduce bus traffic; adjust as needed */
    usleep(1000);
  }

  /* not reached */
  //return 0;
}

// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module frame_manager #(
    parameter integer WBUS_BYTES           = 4,          // AXI-Stream data bus width in bytes (default 32-bit)
    parameter integer AXIL_ADDR_WIDTH      = 6,          // 64B register aperture
    parameter integer AXIL_DATA_WIDTH      = 32
)(
    // Clocks & reset
    input  wire                       clk,               // data plane clock (AXIS/DMA domain)
    input  wire                       rstn,              // active-low sync reset (data clock domain)

    // AXI4-Stream (data producer -> FM -> DMA write channel)
    input  wire [WBUS_BYTES*8-1:0]    s_axis_tdata,
    input  wire                       s_axis_tvalid,
    output wire                       s_axis_tready,
    output reg                        s_axis_tlast,

    // Stream buffer / producer status
    input  wire                       fifo_stream_empty,       // asserted when no data available
    input  wire                       fifo_stream_almost_full, // optional, tie-low if unused

    // DMA handshake (toward AXI DMA S2MM)
    output reg                        dma_start,         // one-cycle start pulse when a frame is ready
    input  wire                       dma_done,          // asserted when current burst completed
    output reg  [31:0]                dma_length_bytes,  // burst length in bytes = FRAME_LEN * WBUS_BYTES

    // DSAS counters (observable)
    output reg  [31:0]                transition_num,    // transactions within the current frame
    output reg  [31:0]                dsas_cycle_num,    // global cycle index (see note below)

    // AXI4-Lite control/status (PS <-> FM)
    input  wire                       s_axi_aclk,
    input  wire                       s_axi_aresetn,
    input  wire [AXIL_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                       s_axi_awvalid,
    output reg                        s_axi_awready,
    input  wire [AXIL_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output reg                        s_axi_wready,
    output reg  [1:0]                 s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  wire                       s_axi_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                       s_axi_arvalid,
    output reg                        s_axi_arready,
    output reg  [AXIL_DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]                 s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  wire                       s_axi_rready
);

    // =========================================================================
    // AXI-Lite Register Map (word-aligned addresses)
    // 0x00 FRAME_LEN   (RW) : LFM, number of transactions per frame
    // 0x04 FRAME_CNT   (RO) : increments on each dma_done
    // 0x08 STATUS      (RO) : {29'd0, eof_pulse, dma_busy, fifo_empty}
    // 0x0C CONTROL     (RW) : {29'd0, force_tlast, manual_reinit, enable}
    // 0x10 TRANS_NUM   (RO) : transition_num
    // 0x14 DSAS_CYCLE  (RO) : dsas_cycle_num
    // 0x18 DMA_LEN_B   (RO) : dma_length_bytes
    // =========================================================================
    localparam [AXIL_ADDR_WIDTH-1:0] REG_FRAME_LEN  = 6'h00;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_FRAME_CNT  = 6'h04;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_STATUS     = 6'h08;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_CONTROL    = 6'h0C;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_TRANS_NUM  = 6'h10;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_DSAS_CYC   = 6'h14;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_DMA_LENB   = 6'h18;

    // Registers
    reg [31:0] FRAME_LEN;     // programmable frame length (transactions)
    reg [31:0] FRAME_CNT;     // frame counter (increments on dma_done)
    reg        ctrl_enable;   // CONTROL[0]
    reg        ctrl_reinit;   // CONTROL[1] (self-clear)
    reg        ctrl_force_tl; // CONTROL[2] (self-clear)
    wire       fifo_empty_status;
    reg        dma_busy;
    reg        eof_pulse;     // one-shot on frame boundary

    assign fifo_empty_status = fifo_stream_empty;

    // =========================================================================
    // AXI-Lite slave simple implementation
    // =========================================================================
    // Write address/ready
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
        end else begin
            s_axi_awready <= s_axi_awvalid && !s_axi_awready && s_axi_wvalid && !s_axi_wready;
        end
    end

    // Write data/ready + register write
    wire write_fire = s_axi_awvalid && s_axi_awready && s_axi_wvalid && !s_axi_wready;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_wready   <= 1'b0;
            FRAME_LEN      <= 32'd64; // nominal per paper
            FRAME_CNT      <= 32'd0;
            ctrl_enable    <= 1'b0;
            ctrl_reinit    <= 1'b0;
            ctrl_force_tl  <= 1'b0;
        end else begin
            s_axi_wready <= s_axi_awvalid && !s_axi_wready && s_axi_wvalid;

            if (write_fire) begin
                case (s_axi_awaddr & {{(AXIL_ADDR_WIDTH-2){1'b1}}, 2'b00})
                    REG_FRAME_LEN: begin
                        if (s_axi_wstrb[0]) FRAME_LEN[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) FRAME_LEN[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) FRAME_LEN[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) FRAME_LEN[31:24] <= s_axi_wdata[31:24];
                    end
                    REG_CONTROL: begin
                        // CONTROL: [0]=enable, [1]=manual_reinit (self-clear), [2]=force_tlast (self-clear)
                        if (s_axi_wstrb != 4'b0000) begin
                            ctrl_enable   <= s_axi_wdata[0];
                            ctrl_reinit   <= s_axi_wdata[1];
                            ctrl_force_tl <= s_axi_wdata[2];
                        end
                    end
                    default: ;
                endcase
            end

            // self-clear one-shot control bits when seen by data-plane domain (sync below)
            if (ctrl_reinit_seen)  ctrl_reinit  <= 1'b0;
            if (ctrl_force_tl_seen)ctrl_force_tl<= 1'b0;
        end
    end

    // Write response
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (write_fire && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Read address
    reg [AXIL_ADDR_WIDTH-1:0] araddr_q;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= {AXIL_DATA_WIDTH{1'b0}};
            s_axi_rresp   <= 2'b00;
            araddr_q      <= {AXIL_ADDR_WIDTH{1'b0}};
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                araddr_q      <= s_axi_araddr & {{(AXIL_ADDR_WIDTH-2){1'b1}}, 2'b00};
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                // capture data for read
                case (araddr_q)
                    REG_FRAME_LEN: s_axi_rdata <= FRAME_LEN;
                    REG_FRAME_CNT: s_axi_rdata <= FRAME_CNT;
                    REG_STATUS:    s_axi_rdata <= {29'd0, eof_pulse, dma_busy, fifo_empty_status};
                    REG_CONTROL:   s_axi_rdata <= {29'd0, ctrl_force_tl, ctrl_reinit, ctrl_enable};
                    REG_TRANS_NUM: s_axi_rdata <= transition_num;
                    REG_DSAS_CYC:  s_axi_rdata <= dsas_cycle_num;
                    REG_DMA_LENB:  s_axi_rdata <= dma_length_bytes;
                    default:       s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00; // OKAY
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Cross-domain synchronizers: CONTROL one-shots into data plane
    // =========================================================================
    // Simple 2FF sync
    reg [1:0] reinit_sync, force_sync, enable_sync;
    always @(posedge clk) begin
        if (!rstn) begin
            reinit_sync  <= 2'b00;
            force_sync   <= 2'b00;
            enable_sync  <= 2'b00;
        end else begin
            reinit_sync  <= {reinit_sync[0],  ctrl_reinit};
            force_sync   <= {force_sync[0],   ctrl_force_tl};
            enable_sync  <= {enable_sync[0],  ctrl_enable};
        end
    end
    wire ctrl_enable_dp   = enable_sync[1];
    wire ctrl_reinit_dp   = reinit_sync[1];
    wire ctrl_force_tl_dp = force_sync[1];

    // Edge detectors to create one-cycle "seen" pulses back in AXI-Lite domain
    reg reinit_seen_dp, force_seen_dp;
    always @(posedge clk) begin
        if (!rstn) begin
            reinit_seen_dp <= 1'b0;
            force_seen_dp  <= 1'b0;
        end else begin
            reinit_seen_dp <= ctrl_reinit_dp;
            force_seen_dp  <= ctrl_force_tl_dp;
        end
    end
    wire ctrl_reinit_seen = reinit_seen_dp;
    wire ctrl_force_tl_seen = force_seen_dp;

    // =========================================================================
    // Data-plane FSM: Idle -> Capture -> Transfer
    // =========================================================================
    localparam [1:0] ST_IDLE    = 2'd0;
    localparam [1:0] ST_CAPTURE = 2'd1;
    localparam [1:0] ST_TRANSFER= 2'd2;

    reg [1:0] state, state_n;

    // Transaction accept handshake
    wire accept = s_axis_tvalid && s_axis_tready;

    // tready gating: hold off when DMA busy or FIFO near full/empty hazards
    //   - Do not accept when fifo is empty (no data)
    //   - Backpressure when DMA busy or almost_full reported
    assign s_axis_tready = (state == ST_CAPTURE) &&
                           !dma_busy &&
                           !fifo_stream_almost_full &&
                           !fifo_stream_empty;

    // Counters and events
    wire frame_boundary_reached = (transition_num == FRAME_LEN - 1);
    reg  fifo_stream_empty_d;
    wire fifo_stream_empty_neg = (fifo_stream_empty_d == 1'b1) && (fifo_stream_empty == 1'b0); // 1->0

    always @(posedge clk) begin
        if (!rstn) begin
            fifo_stream_empty_d <= 1'b1;
        end else begin
            fifo_stream_empty_d <= fifo_stream_empty;
        end
    end

    // FSM next-state logic
    always @(*) begin
        state_n = state;
        case (state)
            ST_IDLE: begin
                if (ctrl_enable_dp) begin
                    state_n = ST_CAPTURE;
                end
            end
            ST_CAPTURE: begin
                if (accept && frame_boundary_reached) begin
                    state_n = ST_TRANSFER;
                end
            end
            ST_TRANSFER: begin
                if (dma_done) begin
                    state_n = ST_CAPTURE;
                end
            end
            default: state_n = ST_IDLE;
        endcase
    end

    // FSM registers and outputs
    always @(posedge clk) begin
        if (!rstn) begin
            state            <= ST_IDLE;
            transition_num   <= 32'd0;
            dsas_cycle_num   <= 32'd0;
            s_axis_tlast     <= 1'b0;
            dma_start        <= 1'b0;
            dma_busy         <= 1'b0;
            dma_length_bytes <= WBUS_BYTES * 32'd64;
            FRAME_CNT        <= 32'd0;
            eof_pulse        <= 1'b0;
        end else begin
            state <= state_n;

            // default outputs
            dma_start <= 1'b0;
            s_axis_tlast <= 1'b0;
            eof_pulse <= 1'b0;

            // manual reinit
            if (ctrl_reinit_dp) begin
                transition_num <= 32'd0;
            end

            // DSAS global cycle index tracking:
            //   Preserve user's original intent (increment on non-empty transition),
            //   or increment on each accepted beat. Here we follow falling edge of empty.
            if (fifo_stream_empty_neg) begin
                dsas_cycle_num <= dsas_cycle_num + 32'd1;
            end

            case (state)
                ST_IDLE: begin
                    dma_busy <= 1'b0;
                    if (ctrl_enable_dp) begin
                        transition_num   <= 32'd0;
                        dma_length_bytes <= FRAME_LEN * WBUS_BYTES[31:0];
                    end
                end
                ST_CAPTURE: begin
                    // Accept beats and count transactions in current frame
                    if (accept) begin
                        transition_num <= transition_num + 32'd1;

                        // TLAST at boundary or when forced by control
                        if (frame_boundary_reached || ctrl_force_tl_dp) begin
                            s_axis_tlast <= 1'b1;
                            eof_pulse    <= 1'b1;
                        end
                    end

                    // When boundary reached and we just accepted it, arm DMA
                    if (accept && (frame_boundary_reached || ctrl_force_tl_dp)) begin
                        dma_length_bytes <= FRAME_LEN * WBUS_BYTES[31:0]; // update if FRAME_LEN changed
                        dma_start        <= 1'b1;     // one-cycle pulse
                        dma_busy         <= 1'b1;
                        transition_num   <= 32'd0;    // re-arm for next frame
                    end
                end

                ST_TRANSFER: begin
                    // Hold busy until dma_done
                    if (dma_done) begin
                        dma_busy  <= 1'b0;
                        FRAME_CNT <= FRAME_CNT + 32'd1;
                    end
                end
            endcase
        end
    end

endmodule