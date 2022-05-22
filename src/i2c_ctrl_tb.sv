
`include "i2c_vip.sv"

module i2c_ctrl_tb (
  );

  logic       clk;
  logic       rstn;
  logic       busy;
  logic       feed;

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
    .busy(busy),
    .feed(feed),

    .addr(addr),
    .data(data)
  );

  I2CVip i2c_vip = new (i2c);

  assign data = !addr[0] ? data_reg : 'hZZ;

  always #0.5 clk = !clk;

  pullup pullup_sda(i2c.sda);
  pullup pullup_scl(i2c.scl);

  initial begin
    addr <= 'hFF;
    data_reg <= 'hFF;
    rstn <= 'b0;
    clk <= 'b0;
    feed <= 'b1;

    #2;
    addr <= 'hA0;
    data_reg <= 'h55;
    rstn <= 'b1;

    @(negedge busy);

    #2;
    addr <= 'hAF;
    rstn <= 'b1;

    @(negedge busy);

    #300;
    $finish;
  end


  initial begin
    byte addr;
    byte data [];

    i2c_vip.xmit_read(1, addr,data);
    i2c_vip.xmit_write(1, addr, '{ 'hAF });

    #30;
    $finish;
  end

endmodule;
