
`include "i2c_vip.sv"

module i2c_ctrl_tb (
  );

  logic       clk;
  logic       rstn;
  logic       en;

  logic [7:0] addr;
   wire [7:0] data;

  logic [7:0] data_reg;

  i2c_if i2c ();
  i2c_ctrl i2c_ctrl (
    .i2c(i2c),

    .clk(clk),
    .rstn(rstn),
    .en(en),

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
    data_reg <= 'h55;
    rstn <= 'b1;
    en <= 'b0;


    #300;
    $finish;
  end

  initial begin
    byte bytes [];
    event start_bit;
    event stop_bit;

    $display("[%d] ================================", $time);
    i2c_vip.detect_start(start_bit);
    $display("[%d] ================================", $time);
    i2c_vip.read(1, bytes);
    #10;
    $display("[%d] ================================", $time);
    i2c_vip.write(1, '{ 'hDD });
    $display("[%d] ================================", $time);

    i2c_vip.detect_stop(stop_bit);
    #30;
    $finish;
  end

endmodule;
