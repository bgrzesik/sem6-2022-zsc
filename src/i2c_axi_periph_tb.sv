`timescale 1ns / 1ps

import axi_vip_pkg::*;
import design_axi_vip_axi_vip_0_0_pkg::*;

module i2c_axi_periph_tb();

  localparam BASE_ADDR = 'h44A00000;
  
  localparam CTRL_ADDR = BASE_ADDR + 'h00;
  localparam DATA_ADDR = BASE_ADDR + 'h04;

  bit aclk;
  bit aresetn;

  wire scl;
  wire sda;

  typedef struct packed {
    bit [31:8] __unused0;
    bit /*7*/  tx_ack;
    bit /*6*/  rx_ack;
    bit [5:4]  __unused1;
    bit /*3*/  idle;
    bit /*2*/  busy;
    bit /*1*/  feed;
    bit /*0*/  rstn;
  } i2c_axi_ctrl;

  typedef struct packed {
    bit [31:24] __unused0;
    bit [23:16] rx_data;
    bit [15:8]  tx_data;
    bit [7:0]   addr;
  } i2c_axi_data;

  task axi_data_read(output i2c_axi_data axi_data);
    bit [31:0] value;
    vip.AXI4LITE_READ_BURST(DATA_ADDR, prot, value, resp);
    axi_data = value;
    $display("[%d] READ  DATA=%h rx=%h tx=%h addr=%h", $time, value, axi_data.rx_data, axi_data.tx_data, axi_data.addr);
  endtask

  task axi_ctrl_read(output i2c_axi_ctrl axi_ctrl);
    bit [31:0] value;
    vip.AXI4LITE_READ_BURST(CTRL_ADDR, prot, value, resp);
    axi_ctrl = value;
    $display("[%d] READ  CTRL=%h rstn=%d feed=%d busy=%d idle=%d rx_ack=%d tx_ack=%d", 
      $time, value, axi_ctrl.rstn, axi_ctrl.feed, axi_ctrl.busy, axi_ctrl.idle, axi_ctrl.rx_ack, axi_ctrl.tx_ack);
  endtask

  task axi_data_write(input i2c_axi_data axi_data);
    bit [31:0] value = axi_data;
    $display("[%d] WRITE DATA=%h rx=%h tx=%h addr=%h", $time, value, axi_data.rx_data, axi_data.tx_data, axi_data.addr);
    vip.AXI4LITE_WRITE_BURST(DATA_ADDR, prot, value, resp);
  endtask

  task axi_ctrl_write(input i2c_axi_ctrl axi_ctrl);
    bit [31:0] value = axi_ctrl;
    $display("[%d] WRITE CTRL=%h rstn=%d feed=%d busy=%d idle=%d rx_ack=%d tx_ack=%d", 
      $time, value, axi_ctrl.rstn, axi_ctrl.feed, axi_ctrl.busy, axi_ctrl.idle, axi_ctrl.rx_ack, axi_ctrl.tx_ack);
    vip.AXI4LITE_WRITE_BURST(CTRL_ADDR, prot, value, resp);
  endtask

  design_axi_vip_axi_vip_0_0_mst_t vip;
  xil_axi_prot_t prot = 0;
  xil_axi_resp_t resp;

  design_axi_vip design_axi_vip(
    .aclk(aclk),
    .aresetn(aresetn),

    .scl(scl),
    .sda(sda)
  );

  always #5ns aclk = !aclk;

  initial begin
    i2c_axi_data axi_data;
    i2c_axi_ctrl axi_ctrl;
    integer value;
    vip = new ("vip", design_axi_vip.axi_vip_0.inst.IF);

    // vip.set_verbosity(400);
    vip.start_master();

    #10ns aresetn <= 'b1;

    axi_ctrl_read(axi_ctrl);
    axi_data_read(axi_data);

    axi_ctrl.rstn = 1;
    axi_ctrl_write(axi_ctrl);
    axi_ctrl_read(axi_ctrl);

    axi_data.addr = 'hF0;
    axi_data.tx_data = 'hAA;
    axi_data_write(axi_data);
    axi_data_read(axi_data);

/*
    #50ns;
    vip.AXI4LITE_WRITE_BURST(CTRL_ADDR, prot, 32'h00000000, resp);
    vip.AXI4LITE_WRITE_BURST(DATA_ADDR, prot, 32'h00000000, resp);
    #50ns;

    vip.AXI4LITE_READ_BURST(CTRL_ADDR, prot, value, resp);
    $display("[%d] READ %h = %h", $time, CTRL_ADDR, value);

    vip.AXI4LITE_WRITE_BURST(CTRL_ADDR, prot, 32'h42002400, resp);

    vip.AXI4LITE_READ_BURST(CTRL_ADDR, prot, value, resp);
    $display("[%d] READ %h = %h", $time, CTRL_ADDR, value);

    vip.AXI4LITE_WRITE_BURST(DATA_ADDR, prot, 32'h42002400, resp);
    #50ns;
    vip.AXI4LITE_WRITE_BURST(CTRL_ADDR, prot, 32'hFFFF00FF, resp);

    vip.AXI4LITE_READ_BURST(CTRL_ADDR, prot, value, resp);
    $display("[%d] READ %h = %h", $time, CTRL_ADDR, value);

    vip.AXI4LITE_WRITE_BURST(ADDR_ADDR, prot, 32'h42F0F4F0, resp);

    #50ns;
    vip.AXI4LITE_WRITE_BURST(ADDR_ADDR, prot, 32'h0000F003, resp);
*/

    #500ns $finish;
  end

endmodule
