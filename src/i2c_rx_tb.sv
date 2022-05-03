`timescale 1ns / 1ps

`include "i2c_vip.sv"

module i2c_rx_tb(
  );

  logic       clk;
  logic       rstn;
  logic       rx;

  logic [7:0] data;
  logic       data_rdy;

  logic       ack_en;
  logic       ack;

  i2c_if i2c ();
  i2c_rx i2c_rx (
    .i2c(i2c.ctrl_rx),

    .clk(clk),
    .rstn(rstn),
    .rx(rx),

    .data(data),
    .data_rdy(data_rdy),

    .ack(ack),
    .ack_en(ack_en)
  );

  I2CVip i2c_vip = new (i2c);

  always #5 clk = !clk;

  // pullup pullup_sda(i2c.sda);
  // pullup pullup_scl(i2c.scl);
  
  task rx_read(input int count, output byte bytes []);
    bytes = new [0];
    rx <= 1'b0;

    for (int i = 0; i < count; i++) begin
      @(negedge data_rdy);

      bytes = new [bytes.size() + 1] (bytes);
      bytes[bytes.size() - 1] = data;

      $display("[%d] controller read %h", $time, data);
    end

    rx <= 1'b1;
  endtask

  initial begin
    @(negedge ack_en);
    ack <= 'b0;
  end

  byte bytes [];

  initial begin
    clk <= 'b0;
    data <= 'hFF;
    rx <= 'b1;
    rstn <= 'b0;
    ack <= 'b1;


    #7;
    rstn <= 1'b1;

    rx_read(1, bytes);
    rx_read(3, bytes);
    rx_read(2, bytes);
  end

  initial begin
    #10;
    $display("=====================================");
    i2c_vip.write(1, '{ 'h55 });
    $display("=====================================");
    i2c_vip.write(3, '{ 'hAA, 'h55, 'hF0 });
    $display("=====================================");
    i2c_vip.write(2, '{ 'hAA, 'h55, 'hF0 });
    $display("=====================================");
    #30;
    $finish;
  end;

endmodule

