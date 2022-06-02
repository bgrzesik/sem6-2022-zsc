
module i2c_rx #(
  parameter CLK_FREQ=50_000_000,
  parameter CLK_DIV=CLK_FREQ / 100_000,
  parameter DIV_LEN = 16
) (
    inout wire                  i2c_scl,
    inout wire                  i2c_sda,

     input wire                 clk,
     input wire                 rstn,
     input wire                 rx,
     input wire [DIV_LEN - 1:0] clk_counter,

    output bit  [7:0]           data,
    output wire                 data_rdy, // Data Ready, active on low

    output wire                 ack_en,   // Ack Enable, active on low
     input wire                 ack       // Ack input
  );

  typedef enum bit [0:4] {
    kIdle    = 0,
    kReceive = 1,
    kAck     = 2
  } state_t;

  state_t state, state_next;

  bit [0:7] data_reg;

  bit [3:0] counter;
  bit [3:0] counter_next;

  bit       was_low;

  // SDA driver
  assign i2c_sda = (was_low & state == kAck) ? ack : 'bZ;

  // Ack Enable driver
  assign ack_en = !(state == kAck & !(was_low & clk_counter == CLK_DIV - 1));

  // Data Ready driver
  assign data_rdy = !(state == kAck);
  assign data = data_reg;

  always @ (negedge clk) begin
    if (! rstn | state == kIdle) begin
      counter_next <= 8'd7;
      data_reg <= 8'h00;
      //data <= 8'h00;
      was_low <='b0;

      if (!rx) 
        state_next <= kReceive;
      else
        state_next <= kIdle;

    end else begin
      case (state)

        kReceive: begin
          if (i2c_scl & was_low) begin
            data_reg[counter] <= i2c_sda;

            if (counter_next != 8'd0) begin
              counter_next <= counter - 1;
            end else begin
              counter_next <= 8'd7;
              state_next <= kAck;

              $display("[%d] [RX] read %h", $time, {i2c_sda, data_reg[1:7]});
            end
            was_low <= 'b0;
          end

          if (!i2c_scl & !was_low) was_low <= 'b1;
        end

        kAck: begin
          if (i2c_scl & was_low & clk_counter == CLK_DIV - 1) begin
            if (!ack & !rx) begin
              counter_next <= 4'd7;
              state_next <= kReceive;
            end else begin
              state_next <= kIdle;
            end
            data_reg <= 'h00;
            was_low <= 'b0;
          end

          if (!i2c_scl & !was_low) was_low <= 'b1;
        end

      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;
  end

endmodule

