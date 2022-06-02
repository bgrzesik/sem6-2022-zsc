`timescale 1ns / 1ps

`include "i2c_vip.sv"

import axi_vip_pkg::*;
import design_axi_vip_axi_vip_0_0_pkg::*;

module i2c_axi_periph_tb();

  localparam BASE_ADDR = 'h44A00000;
  
  localparam CTRL_ADDR = BASE_ADDR + 'h00;
  localparam DATA_ADDR = BASE_ADDR + 'h04;

  bit aclk;
  bit aresetn;

  // wire scl;
  // wire sda;

  design_axi_vip_axi_vip_0_0_mst_t axi_vip = new ("vip", design_axi_vip.axi_vip_0.inst.IF);
  xil_axi_prot_t prot = 0;
  xil_axi_resp_t resp;

  i2c_if i2c ();

  pullup scl_pullup(i2c.scl);
  pullup sda_pullup(i2c.sda);

  design_axi_vip design_axi_vip(
    .aclk(aclk),
    .aresetn(aresetn),

    .scl(i2c.scl),
    .sda(i2c.sda)
  );

  always #1ns aclk = !aclk;

  I2CVip i2c_vip = new (i2c);

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
    byte __unused0;
    byte rx_data;
    byte tx_data;
    byte addr;
  } i2c_axi_data;

  i2c_axi_ctrl CTRL_REGISTER;
  i2c_axi_data DATA_REGISTER;

  task axi_data_read(output i2c_axi_data axi_data);
    bit [31:0] value;
    axi_vip.AXI4LITE_READ_BURST(DATA_ADDR, prot, value, resp);
    axi_data = value;
    DATA_REGISTER = value;
    // $display("[%d] [AXI] READ  DATA=%h rx=%h tx=%h addr=%h", $time, value, axi_data.rx_data, axi_data.tx_data, axi_data.addr);
  endtask

  task axi_ctrl_read(output i2c_axi_ctrl axi_ctrl);
    bit [31:0] value;
    axi_vip.AXI4LITE_READ_BURST(CTRL_ADDR, prot, value, resp);
    axi_ctrl = value;
    CTRL_REGISTER = value;
    // $display("[%d] [AXI] READ  CTRL=%h rstn=%d feed=%d busy=%d idle=%d rx_ack=%d tx_ack=%d", 
    //   $time, value, axi_ctrl.rstn, axi_ctrl.feed, axi_ctrl.busy, axi_ctrl.idle, axi_ctrl.rx_ack, axi_ctrl.tx_ack);
  endtask

  task axi_data_write(input i2c_axi_data axi_data);
    bit [31:0] value;
    value = axi_data;
    $display("[%d] [AXI] WRITE DATA=%h rx=%h tx=%h addr=%h", $time, value, axi_data.rx_data, axi_data.tx_data, axi_data.addr);
    axi_vip.AXI4LITE_WRITE_BURST(DATA_ADDR, prot, value, resp);
  endtask

  task automatic axi_ctrl_write(input i2c_axi_ctrl axi_ctrl);
    bit [31:0] value;
    value = axi_ctrl;
    $display("[%d] [AXI] WRITE CTRL=%h rstn=%d feed=%d busy=%d idle=%d rx_ack=%d tx_ack=%d", 
      $time, value, axi_ctrl.rstn, axi_ctrl.feed, axi_ctrl.busy, axi_ctrl.idle, axi_ctrl.rx_ack, axi_ctrl.tx_ack);
    axi_vip.AXI4LITE_WRITE_BURST(CTRL_ADDR, prot, value, resp);
  endtask

  task ctrl_transaction(input byte target_addr, inout byte xmit_data []);
    i2c_axi_ctrl axi_ctrl;
    i2c_axi_data axi_data;

    // Turn on the controller
    $display("[%d] [TB] turning on controller", $time);
    axi_ctrl.rstn = 'b1;
    axi_ctrl.feed = 'b1;
    axi_ctrl_write(axi_ctrl);

    $display("[%d] [TB] waiting for controller to finish previous transaction", $time);
    do begin
      axi_ctrl_read(axi_ctrl);
    end while (axi_ctrl.idle);

    // Start transaction and Wait until we can provide address
    $display("[%d] [TB] transaction start, waiting to provide address", $time);
    axi_ctrl.feed = 'b0;
    axi_ctrl_write(axi_ctrl);

    do begin
      axi_ctrl_read(axi_ctrl);
    end while (axi_ctrl.busy);

    $display("[%d] [TB] controller not busy, providing address", $time);
    axi_data.addr = target_addr;
    axi_data_write(axi_data);

    $display("[%d] [TB] address %h provided, waiting for busy flag", $time, target_addr);
    do begin
      axi_ctrl_read(axi_ctrl);
    end while (!axi_ctrl.busy);

    $display("[%d] [TB] waiting for controller to finish sending address", $time);
    do begin
      axi_ctrl_read(axi_ctrl);
    end while (axi_ctrl.busy);

    if (axi_ctrl.tx_ack) $finish;

    foreach (xmit_data[i]) begin
      if (!axi_data.addr[0]) begin
        $display("[%d] [TB] send %h", $time, xmit_data[i]);
        axi_data.tx_data = xmit_data[i];
        axi_data_write(axi_data);
      end

      $display("[%d] [TB] waiting for controller to become busy", $time);
      do begin
        axi_ctrl_read(axi_ctrl);
      end while (!axi_ctrl.busy);

      if (target_addr[0]) begin
        axi_ctrl.rx_ack = 'b1;
        axi_ctrl_write(axi_ctrl);
      end

      $display("[%d] [TB] controller busy", $time);
      do begin
        axi_ctrl_read(axi_ctrl);
      end while (axi_ctrl.busy);

      if (!target_addr[0] & axi_ctrl.tx_ack) begin
        $display("[%d] [TB] got more rx_data to send but got NAK", $time);
        $finish;
      end else if (target_addr[0]) begin
        axi_data_read(axi_data);
        xmit_data[i] = axi_data.rx_data;
        $display("[%d] [TB] read %h giving ACK", $time, axi_data.rx_data);

        axi_ctrl.rx_ack = 'b0;
        axi_ctrl_write(axi_ctrl);
      end
    end

    $display("[%d] [TB] no more data, waiting for controller to finish transaction", $time);
    axi_ctrl.feed = 'b1;
    axi_ctrl_write(axi_ctrl);

    do begin
      axi_ctrl_read(axi_ctrl);
    end while (axi_ctrl.idle);
    $display("[%d] [TB] transaction finished", $time);
  endtask

  task test_tx(input byte target_addr, input byte xmit_data []);
    byte rx_addr;
    byte rx_data_buf [];

    if (target_addr[0]) $finish;

    fork
      i2c_vip.xmit_read(xmit_data.size(), rx_addr, rx_data_buf);
      ctrl_transaction(target_addr, xmit_data);
    join

    $display("[%d] [TEST] Address GOT: %h EXPECTED: %h", $time, rx_addr, target_addr);
    if (rx_addr != target_addr) $finish;

    foreach (xmit_data[i]) begin
      $display("[%d] [TEST] data[%d] GOT: %h EXPECTED: %h", $time, i, rx_data_buf[i], xmit_data[i]);
    end

    if (rx_data_buf != xmit_data) $finish;
  endtask

  task test_rx(input byte target_addr, input byte xmit_data []);
    byte rx_addr;
    byte rx_data_buf [];

    if (!target_addr[0]) $finish;

    rx_data_buf = new [xmit_data.size()];

    fork
      i2c_vip.xmit_write(xmit_data.size(), rx_addr, xmit_data);
      ctrl_transaction(target_addr, rx_data_buf);
    join

    $display("[%d] [TEST] Address GOT: %h EXPECTED: %h", $time, rx_addr, target_addr);
    if (rx_addr != target_addr) $finish;

    foreach (xmit_data[i]) begin
      $display("[%d] [TEST] data[%d] GOT: %h EXPECTED: %h", $time, i, rx_data_buf[i], xmit_data[i]);
    end

    if (rx_data_buf != xmit_data) $finish;
  endtask

  class Transaction;
    rand  byte addr;
    randc byte data [];

    constraint c_data_size { data.size() >= 1; data.size() < 8; }
  endclass

  initial begin
    Transaction transaction;

    axi_vip.start_master();
    #10ns aresetn <= 'b1;

    transaction = new ();
    transaction.addr = 'h11;
    transaction.data = new [0];
    test_rx(transaction.addr, transaction.data);

    transaction = new ();
    transaction.addr = 'h12;
    transaction.data = new [0];
    test_tx(transaction.addr, transaction.data);

    for (int i = 0; i < 12; i++) begin
      transaction = new ();
      transaction.randomize();

      $display("[%d] ============== TEST CASE ==============", $time);
      $display("[%d] ADDR: %h, len(DATA) = %d", $time, transaction.addr, transaction.data.size());
      foreach (transaction.data[j])
        $display("[%d] DATA[%d] = %h", $time, j, transaction.data[j]);

      if (transaction.addr[0])
        test_rx(transaction.addr, transaction.data);
      else
        test_tx(transaction.addr, transaction.data);
    end

    #100ns $finish;
  end

endmodule
