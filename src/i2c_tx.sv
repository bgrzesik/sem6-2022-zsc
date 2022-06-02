
module i2c_tx #( 
  parameter CLK_FREQ=50_000_000,
  parameter CLK_DIV=CLK_FREQ / 100_000,
  parameter DIV_LEN = 16
) (
    inout wire                  i2c_sda,
    inout wire                  i2c_scl,

     input wire                 clk,
     input wire                 rstn,
     input wire                 tx,

     input wire [7:0]           data,
     input wire [DIV_LEN - 1:0] clk_counter,

    output bit                  data_en, // Data Enable, active on low

    output bit                  ack_en,  // Ack Enable, active on low
    output bit                  ack      // Ack State, ACK on low, NAK on high
  );

  typedef enum bit [0:2] {
    kIdle     = 0,
    kTransmit = 1,
    kAck      = 2
  } state_t;

  state_t state, state_next;

  bit [7:0] data_reg;

  bit [3:0] counter;
  bit [3:0] counter_next;

  bit       was_high;

  // SDA driver
  assign i2c_sda = (state == kTransmit & !data_reg[counter]) ? 'b0 : 'bZ;

  // Data Enable driver
  assign data_en = !(state == kIdle | (state == kAck & !ack));

  always @ (negedge clk) begin 
    if (! rstn | state == kIdle) begin
      ack <= 1'b1;
      ack_en <= 1'b1;

      data_reg <= 8'hFF;
      counter_next <= 4'd7;
      was_high <= 'b0;

      if (! tx) begin
        // data_reg <= data;
        state_next <= kTransmit;
      end else begin
        state_next <= kIdle;
      end

    end else begin
      case (state)
        kTransmit: begin
          if (counter_next == 'd7 & !i2c_scl)
            data_reg <= data;

          if (was_high & !i2c_scl & counter_next == 'd0) begin
            state_next <= kAck;
          end else if (was_high & !i2c_scl) begin
            counter_next <= counter_next - 1;
            was_high <= 'b0;
          end else if (i2c_scl) begin
            was_high <= 'b1;
          end
        end

        kAck: begin
          if (i2c_scl) begin
            ack <= i2c_sda ? 1'b1 : 1'b0;
            ack_en <= 1'b0;

            $display("[%d] [TX] ack = %d", $time, i2c_sda);
          end

          if (clk_counter == CLK_DIV - 1) begin
            if (!ack & !tx) begin
              data_reg <= data;
              state_next <= kTransmit;
            end else begin
              state_next <= kIdle;
            end

            was_high <= 'b0;
            counter_next <= 4'd7;
            ack_en <= 1'b1;
          end
        end
      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;
  end

endmodule

