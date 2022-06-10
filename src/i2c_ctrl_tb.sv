
`include "i2c_vip.sv"

module i2c_ctrl_tb (
  );

  logic       clk;
  logic       rstn;
  wire        busy;
  logic       feed;
  wire        idle;
  logic       rx_ack;
  wire        tx_ack;

  logic [7:0] addr;
  logic [7:0] tx_data;
  wire  [7:0] rx_data;


  i2c_if i2c ();
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
    .IO(i2c.sda),
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
    .IO(i2c.scl),
    .O(i2c_scl_o),
    .I(i2c_scl_i),
    .T(i2c_scl_t)
  );


  i2c_ctrl #(
    .CLK_DIV(10)
  ) i2c_ctrl (
    .i2c_sda_i(i2c_sda_i),
    .i2c_sda_t(i2c_sda_t),
    .i2c_sda_o(i2c_sda_o),

    .i2c_scl_i(i2c_scl_i),
    .i2c_scl_t(i2c_scl_t),
    .i2c_scl_o(i2c_scl_o),
    
    .clk(clk),
    .rstn(rstn),
    .feed(feed),

    .tx_ack(tx_ack),
    .rx_ack(rx_ack),
    .busy(busy),

    .addr(addr),
    .rx_data(rx_data),
    .tx_data(tx_data),

    .idle(idle)
  );

  I2CVip i2c_vip = new (i2c);

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
        tx_data <= xmit_data[i];
      end else begin
        tx_data <= 'hZZ;
      end

      $display("[%d] [TB] waiting for controller to become busy", $time);
      while (!busy) @(negedge clk);
      if (addr[0]) rx_ack <= 'b1;

      $display("[%d] [TB] controller busy", $time);
      while (busy) @(negedge clk);

      if (!addr[0] & tx_ack) begin
        $display("[%d] [TB] got more rx_data to send but got NAK", $time);
        $finish;
      end else if (addr[0]) begin
        $display("[%d] [TB] read %h giving ACK", $time, rx_data);
        xmit_data[i] = rx_data;
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

  initial begin
    byte xmit_data [];

    addr <= 'hFF;
    tx_data <= 'hFF;
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
