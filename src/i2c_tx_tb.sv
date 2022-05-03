`timescale 1ns / 1ps

`include "i2c_vip.sv"

module i2c_tx_tb(
  );
  logic       clk;
  logic       rstn;
  logic       tx;

  logic [7:0] data;

  logic       data_en;
  logic       ack_s;
  logic       ack_en;

  i2c_if i2c ();
  i2c_tx i2c_tx (
    .i2c(i2c.ctrl_tx),

    .clk(clk),
    .rstn(rstn),
    .tx(tx),

    .data(data),

    .data_en(data_en),
    .ack_s(ack_s),
    .ack_en(ack_en)
  );

  I2CVip i2c_vip = new (i2c);

  always #5 clk = !clk;

  pullup pullup_sda(i2c.sda);
  pullup pullup_scl(i2c.scl);


  task tx_write(input int ack_count, byte bytes []);
    tx = 1'b0;

    foreach (bytes[i]) begin
      if (data_en) @(negedge data_en);

      data = bytes[i];

      @(negedge ack_en);

      if (! ack_en & ack_s) begin
        $display("[%d] controller NAK", $time);
        if (ack_count != 0) $finish;
        break;
      end else begin
        $display("[%d] controller ACK", $time);
        ack_count = ack_count - 1;
        if (ack_count < 0) $finish;
      end
    end

    if (ack_count != 0) $finish;

    //@(negedge data_en)
    tx = 1'b1;
  endtask

  task tx_test(input int ack_count, input byte bytes []);
    byte cmp [];

    fork
      tx_write(ack_count, bytes);

      begin
        i2c_vip.read(ack_count, cmp);

        for (int i = 0; i < ack_count; i++) begin
          $display("[%d] got: %h expected: %h", $time, cmp[i], bytes[i]);
          if (bytes[i] != cmp[i]) $finish;
        end
      end

    join

    disable fork;
  endtask

  initial begin
    clk <= 1'b0;
    rstn <= 1'b0;
    data = 8'hFF;
    tx <= 1'b1;
 
    #7 rstn = 1'b1;
    $display("=====================================");
    tx_test(1, '{ 8'hAA });
    $display("=====================================");
    tx_test(2, '{ 8'h55, 8'hF0 });
    $display("=====================================");
    tx_test(2, '{ 8'h0F, 8'hF0 });
    $display("=====================================");
    tx_test(3, '{ 8'h77, 8'h33, 8'h22 });
    $display("=====================================");

    #30;
    $finish;
  end


endmodule

