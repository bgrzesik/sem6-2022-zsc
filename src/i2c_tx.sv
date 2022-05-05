
module i2c_tx (
    i2c_if.ctrl_tx i2c,

     input wire       clk,
     input wire       rstn,
     input wire       tx,

     input wire [7:0] data,
    output bit        data_en, // Data Enable, active on low

    output bit        ack_en,  // Ack Enable, active on low
    output bit        ack      // Ack State, ACK on low, NAK on high
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

  // SDA driver
  assign i2c.sda = (state == kTransmit) ? data_reg[counter] : 'bZ;

  // SCL driver
  assign i2c.scl = (state == kTransmit || state == kAck) ? clk : 'bZ;

  // Data Enable driver
  assign data_en = !(state == kIdle | (state == kAck & !ack));

  always @ (posedge clk) begin 
    case (state)

      kAck: begin
        ack <= i2c.sda ? 1'b1 : 1'b0;
        ack_en <= 1'b0;

        $display("[%d] ack = %d", $time, i2c.sda);
      end

    endcase
  end

  always @ (negedge clk) begin 
    if (! rstn | state == kIdle) begin
      // state_next <= kIdle;
      ack <= 1'b1;
      ack_en <= 1'b1;

      data_reg <= 8'hFF;
      counter_next <= 4'd7;

      if (! tx) begin
        data_reg <= data;
        state_next <= kTransmit;
      end else begin
        state_next <= kIdle;
      end

    end else begin
      case (state)
        kTransmit: begin
          if (counter_next == 4'd0)
            state_next <= kAck;
          else
            counter_next <= counter_next - 1;
        end

        kAck: begin
          if (!ack & !tx) begin
            data_reg <= data;
            counter_next <= 4'd7;
            state_next <= kTransmit;
          end else begin
            counter_next <= 4'd7;
            state_next <= kIdle;
          end
          ack_en <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;
  end

endmodule

