

module i2c_clk_driver #(
  parameter CLK_DIV = 2,
  parameter CLK_DUTY = CLK_DIV / 2,
  parameter DIV_LEN = 16
) (
   input wire                  rstn,
   input wire                  clk,
   input wire                  en,
   inout wire                  clk_out,
  output logic [DIV_LEN - 1:0] counter
);

  logic [DIV_LEN - 1:0] counter_next;

  assign counter = counter_next;

  assign clk_out = (rstn & !en & counter < CLK_DUTY) ? 'b0 : 'bZ;

  always @ (negedge clk) begin
    if (!rstn | en | counter_next >= CLK_DIV - 1) begin
      counter_next <= 0;
    end else begin
      counter_next <= counter_next + 1;
    end
  end

endmodule
