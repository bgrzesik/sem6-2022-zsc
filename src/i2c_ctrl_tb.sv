
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
        $display("[%d] [TB] read %h giving ACK", $time, data);
        xmit_data[i] = data;
        rx_ack <= 'b0;
      end
    end

    $display("[%d] [TB] no more data, waiting for controller to finish transaction", $time);
    feed <= 'b1;
    while (idle) @(negedge clk);
    $display("[%d] [TB] transaction finished", $time);
  endtask

  task test_tx(input byte target_addr, input byte xmit_data []);
    byte rx_addr;
    byte rx_data [];

    if (target_addr[0]) $finish;

    fork
      i2c_vip.xmit_read(xmit_data.size(), rx_addr, rx_data);
      ctrl_transaction(target_addr, xmit_data);
    join

    $display("[%d] [TEST] Address GOT: %h EXPECTED: %h", $time, rx_addr, target_addr);
    if (rx_addr != target_addr) $finish;

    foreach (xmit_data[i]) begin
      $display("[%d] [TEST] data[%d] GOT: %h EXPECTED: %h", $time, i, rx_data[i], xmit_data[i]);
    end

    if (rx_data != xmit_data) $finish;
  endtask

  task test_rx(input byte target_addr, input byte xmit_data []);
    byte rx_addr;
    byte rx_data [];

    if (!target_addr[0]) $finish;

    rx_data = new [xmit_data.size()];

    fork
      i2c_vip.xmit_write(xmit_data.size(), rx_addr, xmit_data);
      ctrl_transaction(target_addr, rx_data);
    join

    $display("[%d] [TEST] Address GOT: %h EXPECTED: %h", $time, rx_addr, target_addr);
    if (rx_addr != target_addr) $finish;

    foreach (xmit_data[i]) begin
      $display("[%d] [TEST] data[%d] GOT: %h EXPECTED: %h", $time, i, rx_data[i], xmit_data[i]);
    end

    if (rx_data != xmit_data) $finish;
  endtask

  initial begin
    byte xmit_data [];

    addr <= 'hFF;
    data_reg <= 'hFF;
    rstn <= 'b0;
    clk <= 'b0;
    feed <= 'b1;
    rx_ack <= 'b1;

    test_tx('h30, '{ 'h12, 'h32, 'h99 });
    test_tx('h34, '{ 'h00, 'hff, 'hac });

    test_rx('h33, '{ 'h12, 'h32, 'h99 });
    test_rx('h31, '{ 'h00, 'hff, 'hac });

    test_tx('h30, '{ 'h12, 'h32, 'h99 });
    test_rx('h31, '{ 'h00, 'hff, 'hac });

    test_rx('h33, '{ 'h12, 'h32, 'h99 });
    test_tx('h34, '{ 'h00, 'hff, 'hac });

    #30;
    $finish;
  end

endmodule;
