
`include "i2c_vip.sv"

module i2c_ctrl_tb (
  );

  logic       clk;
  logic       rstn;
  logic       en;
  logic       busy;

  logic [7:0] addr;
   wire [7:0] data;

  logic [7:0] data_reg;

  i2c_if i2c ();
  i2c_ctrl i2c_ctrl (
    .i2c(i2c),

    .clk(clk),
    .rstn(rstn),
    .en(en),
    .busy(busy),

    .addr(addr),
    .data(data)
  );

  I2CVip i2c_vip = new (i2c);

  assign data = !addr[0] ? data_reg : 'hZZ;

  always #5 clk = !clk;

  // pullup pullup_sda(i2c.sda);
  // pullup pullup_scl(i2c.scl);

  initial begin
    addr <= 'hFF;
    data_reg <= 'hFF;
    rstn <= 'b0;
    en <= 'b1;
    clk <= 'b0;

    #7;
    addr <= 'hAF;
    rstn <= 'b1;
    en <= 'b0;

    @(negedge busy);

    #7;
    addr <= 'hA0;
    data_reg <= 'h55;
    rstn <= 'b1;
    en <= 'b0;

    @(negedge busy);


    #300;
    $finish;
  end


  initial begin
    byte addr;
    byte data [];

    i2c_vip.xmit_write(1, addr, '{ 'hAF });
    i2c_vip.xmit_read(1, addr,data);

    #30;
    $finish;
  end

endmodule;
