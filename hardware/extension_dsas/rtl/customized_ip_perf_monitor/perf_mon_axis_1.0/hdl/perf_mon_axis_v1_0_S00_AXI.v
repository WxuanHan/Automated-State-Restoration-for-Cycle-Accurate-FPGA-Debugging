`timescale 1 ns / 1 ps
// ============================================================================
//  perf_mon_axis_v1_0_S00_AXI.v
//  AXI4-Lite slave wrapper with minimal register map to control/observe
//  the AXIS backpressure monitor.
//
//  Address map (word-aligned):
//    0x00 CONTROL  (W): bit0=CLR, bit1=START, bit2=STOP (one-shot pulse)
//    0x04 ACTIVE   (R): bit0=active
//    0x10 BEATS    (R)
//    0x14 STALL_UP (R)
//    0x18 STALL_DN (R)
//    0x1C CYCLES   (R)
// ============================================================================

module perf_mon_axis_v1_0_S00_AXI #
(
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
  // AXI4-Lite Slave Interface
  input  wire                               S_AXI_ACLK,
  input  wire                               S_AXI_ARESETN,
  input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_AWADDR,
  input  wire [2 : 0]                       S_AXI_AWPROT,
  input  wire                               S_AXI_AWVALID,
  output reg                                S_AXI_AWREADY,
  input  wire [C_S_AXI_DATA_WIDTH-1 : 0]    S_AXI_WDATA,
  input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]  S_AXI_WSTRB,
  input  wire                               S_AXI_WVALID,
  output reg                                S_AXI_WREADY,
  output reg [1 : 0]                        S_AXI_BRESP,
  output reg                                S_AXI_BVALID,
  input  wire                               S_AXI_BREADY,
  input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_ARADDR,
  input  wire [2 : 0]                       S_AXI_ARPROT,
  input  wire                               S_AXI_ARVALID,
  output reg                                S_AXI_ARREADY,
  output reg [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
  output reg [1 : 0]                        S_AXI_RRESP,
  output reg                                S_AXI_RVALID,
  input  wire                               S_AXI_RREADY,

  // ===== User connections to monitor =====
  output reg        mon_clr,
  output reg        mon_start,
  output reg        mon_stop,
  input  wire [31:0] beats,
  input  wire [31:0] stall_up,
  input  wire [31:0] stall_down,
  input  wire [31:0] cycles_meas,
  input  wire        active
);

  // ------------------------------------------------------------
  // Local parameters: addresses (word aligned)
  // ------------------------------------------------------------
  localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CONTROL = 6'h00; // 0x00
  localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_ACTIVE  = 6'h04; // 0x04
  localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_BEATS   = 6'h10; // 0x10
  localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_STALLUP = 6'h14; // 0x14
  localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_STALLDN = 6'h18; // 0x18
  localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CYCLES  = 6'h1C; // 0x1C

  // ------------------------------------------------------------
  // AXI write address/data handshake
  // ------------------------------------------------------------
  reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
  reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

  // Write address ready
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN)
      S_AXI_AWREADY <= 1'b0;
    else if (~S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID)
      S_AXI_AWREADY <= 1'b1;
    else
      S_AXI_AWREADY <= 1'b0;
  end

  // Latch write address
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN)
      axi_awaddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
    else if (~S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID)
      axi_awaddr <= S_AXI_AWADDR;
  end

  // Write data ready
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN)
      S_AXI_WREADY <= 1'b0;
    else if (~S_AXI_WREADY && S_AXI_WVALID && S_AXI_AWVALID)
      S_AXI_WREADY <= 1'b1;
    else
      S_AXI_WREADY <= 1'b0;
  end

  // ------------------------------------------------------------
  // CONTROL register write → one-shot pulses on mon_* signals
  // ------------------------------------------------------------
  wire write_en = S_AXI_WREADY & S_AXI_WVALID & S_AXI_AWREADY & S_AXI_AWVALID;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      mon_clr   <= 1'b0;
      mon_start <= 1'b0;
      mon_stop  <= 1'b0;
    end else begin
      if (write_en && (axi_awaddr == ADDR_CONTROL)) begin
        mon_clr   <= S_AXI_WDATA[0];
        mon_start <= S_AXI_WDATA[1];
        mon_stop  <= S_AXI_WDATA[2];
      end else begin
        // One-shot: clear at next cycle
        mon_clr   <= 1'b0;
        mon_start <= 1'b0;
        mon_stop  <= 1'b0;
      end
    end
  end

  // ------------------------------------------------------------
  // Write response (OKAY)
  // ------------------------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      S_AXI_BVALID <= 1'b0;
      S_AXI_BRESP  <= 2'b00;
    end else if (S_AXI_AWREADY & S_AXI_AWVALID & ~S_AXI_BVALID & S_AXI_WREADY & S_AXI_WVALID) begin
      S_AXI_BVALID <= 1'b1;
      S_AXI_BRESP  <= 2'b00; // OKAY
    end else if (S_AXI_BVALID & S_AXI_BREADY) begin
      S_AXI_BVALID <= 1'b0;
    end
  end

  // ------------------------------------------------------------
  // AXI read address handshake
  // ------------------------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      S_AXI_ARREADY <= 1'b0;
      axi_araddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
    end else if (~S_AXI_ARREADY && S_AXI_ARVALID) begin
      S_AXI_ARREADY <= 1'b1;
      axi_araddr    <= S_AXI_ARADDR;
    end else begin
      S_AXI_ARREADY <= 1'b0;
    end
  end

  // ------------------------------------------------------------
  // AXI read data channel
  // ------------------------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      S_AXI_RVALID <= 1'b0;
      S_AXI_RRESP  <= 2'b00;
      S_AXI_RDATA  <= {C_S_AXI_DATA_WIDTH{1'b0}};
    end else if (S_AXI_ARREADY & S_AXI_ARVALID & ~S_AXI_RVALID) begin
      // prepare read data
      case (axi_araddr)
        ADDR_ACTIVE: S_AXI_RDATA <= {31'b0, active};
        ADDR_BEATS : S_AXI_RDATA <= beats;
        ADDR_STALLUP: S_AXI_RDATA <= stall_up;
        ADDR_STALLDN: S_AXI_RDATA <= stall_down;
        ADDR_CYCLES: S_AXI_RDATA <= cycles_meas;
        default:     S_AXI_RDATA <= 32'h0000_0000;
      endcase
      S_AXI_RRESP <= 2'b00; // OKAY
      S_AXI_RVALID<= 1'b1;
    end else if (S_AXI_RVALID & S_AXI_RREADY) begin
      S_AXI_RVALID<= 1'b0;
    end
  end

endmodule
