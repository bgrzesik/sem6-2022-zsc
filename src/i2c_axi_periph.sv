
`timescale 1 ns / 1 ps

  module i2c_axi_periph #
  (
    // Users to add parameters here
    parameter integer CLK_FREQ=50_000_000,
    // User parameters ends
    // Do not modify the parameters beyond this line


    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter integer C_S00_AXI_DATA_WIDTH  = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH  = 4
  )
  (
    // Users to add ports here
    inout wire sda,
    inout wire scl,
    // User ports ends
    // Do not modify the ports beyond this line


    // Ports of Axi Slave Bus Interface S00_AXI
    input wire  s00_axi_aclk,
    input wire  s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire  s00_axi_awvalid,
    output wire  s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire  s00_axi_wvalid,
    output wire  s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire  s00_axi_bvalid,
    input wire  s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire  s00_axi_arvalid,
    output wire  s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire  s00_axi_rvalid,
    input wire  s00_axi_rready
  );

  wire       i2c_ctrl_rstn;
  wire       i2c_ctrl_feed;
  wire       i2c_ctrl_busy;
  wire       i2c_ctrl_idle;

  wire       i2c_ctrl_rx_ack;
  wire       i2c_ctrl_tx_ack;

  wire [7:0] i2c_ctrl_addr;
  wire [7:0] i2c_ctrl_rx_data;
  wire [7:0] i2c_ctrl_tx_data;

  wire [7:0] dbg_state;

  // Instantiation of Axi Bus Interface S00_AXI
  i2c_axi_periph_axi # ( 
    .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
  ) i2c_axi_periph_axi_inst (
    .i2c_ctrl_rstn(i2c_ctrl_rstn),
    .i2c_ctrl_feed(i2c_ctrl_feed),
    .i2c_ctrl_busy(i2c_ctrl_busy),
    .i2c_ctrl_idle(i2c_ctrl_idle),

    .i2c_ctrl_rx_ack(i2c_ctrl_rx_ack),
    .i2c_ctrl_tx_ack(i2c_ctrl_tx_ack),

    .i2c_ctrl_addr(i2c_ctrl_addr),
    .i2c_ctrl_rx_data(i2c_ctrl_rx_data),
    .i2c_ctrl_tx_data(i2c_ctrl_tx_data),
    .dbg_state(dbg_state),

    .S_AXI_ACLK(s00_axi_aclk),
    .S_AXI_ARESETN(s00_axi_aresetn),
    .S_AXI_AWADDR(s00_axi_awaddr),
    .S_AXI_AWPROT(s00_axi_awprot),
    .S_AXI_AWVALID(s00_axi_awvalid),
    .S_AXI_AWREADY(s00_axi_awready),
    .S_AXI_WDATA(s00_axi_wdata),
    .S_AXI_WSTRB(s00_axi_wstrb),
    .S_AXI_WVALID(s00_axi_wvalid),
    .S_AXI_WREADY(s00_axi_wready),
    .S_AXI_BRESP(s00_axi_bresp),
    .S_AXI_BVALID(s00_axi_bvalid),
    .S_AXI_BREADY(s00_axi_bready),
    .S_AXI_ARADDR(s00_axi_araddr),
    .S_AXI_ARPROT(s00_axi_arprot),
    .S_AXI_ARVALID(s00_axi_arvalid),
    .S_AXI_ARREADY(s00_axi_arready),
    .S_AXI_RDATA(s00_axi_rdata),
    .S_AXI_RRESP(s00_axi_rresp),
    .S_AXI_RVALID(s00_axi_rvalid),
    .S_AXI_RREADY(s00_axi_rready)
  );

  // Add user logic here
  wire i2c_sda_i;
  wire i2c_sda_t;
  wire i2c_sda_o;

  wire i2c_scl_i;
  wire i2c_scl_t;
  wire i2c_scl_o;

  IOBUF #(
    .DRIVE(33),
    .IBUF_LOW_PWR("FALSE"),
    .IOSTANDARD("DEFAULT"),
    .SLEW("SLOW")
  ) iobuf_sda (
    .IO(sda),
    .O(i2c_sda_o),
    .I(i2c_sda_i),
    .T(i2c_sda_t)
  );

  IOBUF #(
    .DRIVE(33),
    .IBUF_LOW_PWR("FALSE"),
    .IOSTANDARD("DEFAULT"),
    .SLEW("SLOW")
  ) iobuf_scl (
    .IO(scl),
    .O(i2c_scl_o),
    .I(i2c_scl_i),
    .T(i2c_scl_t)
  );

  i2c_ctrl #(
    .CLK_FREQ(CLK_FREQ)
  ) i2c_ctrl (
    .i2c_sda_i(i2c_sda_i),
    .i2c_sda_t(i2c_sda_t),
    .i2c_sda_o(i2c_sda_o),

    .i2c_scl_i(i2c_scl_i),
    .i2c_scl_t(i2c_scl_t),
    .i2c_scl_o(i2c_scl_o),

    .clk(s00_axi_aclk),

    .rstn(i2c_ctrl_rstn),
    .feed(i2c_ctrl_feed),
    .busy(i2c_ctrl_busy),
    .idle(i2c_ctrl_idle),

    .tx_ack(i2c_ctrl_tx_ack),
    .rx_ack(i2c_ctrl_rx_ack),

    .addr(i2c_ctrl_addr),
    .rx_data(i2c_ctrl_rx_data),
    .tx_data(i2c_ctrl_tx_data),

    .dbg_state(dbg_state)
  );
  // User logic ends

  endmodule
