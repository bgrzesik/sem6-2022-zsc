
`include "i2c_vip.sv"

module i2c_ctrl_tb (
  );

  logic       clk;
  logic       rstn;
  logic       busy;
  logic       feed;
  logic       idle;
  logic       rx_ack;
  logic       tx_ack;

  logic [7:0] addr;
   wire [7:0] data;

  logic [7:0] data_reg;

  i2c_if i2c ();
  i2c_ctrl #(
    .CLK_DIV(10)
  ) i2c_ctrl (
    .i2c(i2c),

    .clk(clk),
    .rstn(rstn),
    .feed(feed),

    .tx_ack(tx_ack),
    .rx_ack(rx_ack),
    .busy(busy),

    .addr(addr),
    .data(data),

    .idle(idle)
  );

  I2CVip i2c_vip = new (i2c);

  assign data = !addr[0] ? data_reg : 'hZZ;

  always #0.5 clk = !clk;

  pullup pullup_sda(i2c.sda);
  pullup pullup_scl(i2c.scl);

  task ctrl_transaction(input byte target_addr, inout byte xmit_data []);

    // Turn on the controller
    rstn <= 'b1;

    $display("[%d] [TB] waiting for controller to finish previous transaction", $time);
    feed <= 'b1;
    while (idle) @(negedge clk);

    // Start transaction and Wait until we can provide address
    $display("[%d] [TB] transaction start, waiting to provide address", $time);
    feed <= 'b0;
    while (busy) @(negedge clk);
    addr <= target_addr;

    $display("[%d] [TB] address %h provided, waiting for busy flag", $time, target_addr);
    while (!busy) @(negedge clk);

    $display("[%d] [TB] waiting for controller to finish sending address", $time);
    while (busy) @(negedge clk);

    if (tx_ack) $finish;

    foreach (xmit_data[i]) begin
      if (!addr[0]) begin
        $display("[%d] [TB] send %h", $time, xmit_data[i]);
        data_reg <= xmit_data[i];
      end else begin
        data_reg <= 'hZZ;
      end

      $display("[%d] [TB] waiting for controller to become busy", $time);
      while (!busy) @(negedge clk);
      if (addr[0]) rx_ack <= 'b1;

      $display("[%d] [TB] controller busy", $time);
      while (busy) @(negedge clk);

      if (!addr[0] & tx_ack) begin
        $display("[%d] [TB] got more data to send but got NAK", $time);
        $finish;
      end else begin
        $display("[%d] [TB] read %h giving ACK", $time, data_reg);
        rx_ack <= 'b0;
      end
    end

    $display("[%d] [TB] no more data, waiting for controller to finish transaction", $time);
    feed <= 'b1;
    while (idle) @(negedge clk);
    $display("[%d] [TB] transaction finished", $time);
  endtask

  initial begin
    byte xmit_data [];

    addr <= 'hFF;
    data_reg <= 'hFF;
    rstn <= 'b0;
    clk <= 'b0;
    feed <= 'b1;
    tx_ack <= 'b1;
    rx_ack <= 'b1;

    xmit_data = '{ 'h55 };
    ctrl_transaction('hA0, xmit_data);

    xmit_data = '{ 'h05, 'h12, 'hd7 };
    ctrl_transaction('h32, xmit_data);

    xmit_data = new [2];
    ctrl_transaction('h33, xmit_data);

    #30;
    $finish;
  end


  initial begin
    byte addr;
    byte data [];

    i2c_vip.xmit_read(1, addr, data);
    i2c_vip.xmit_read(3, addr, data);

    i2c_vip.xmit_write(2, addr, '{ 'hAB, 'hCC });

    #30;
    $finish;
  end

endmodule;
