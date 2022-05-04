
module i2c_tx (
    i2c_if.ctrl_tx i2c,

    input logic       clk,
    input logic       rstn,
    input logic       tx,

    input logic [7:0] data,

    output bit        data_en, // Data Enable, active on low
    output bit        ack_en,  // Ack Enable, active on low
    output bit        ack      // Ack State, ACK on low, NAK on high
  );

  typedef enum logic [0:2] {
    kIdle     = 0,
    kTransmit = 1,
    kAck      = 2
  } state_t;

  state_t state, state_next;

  logic [7:0] data_reg;

  logic [3:0] counter;
  logic [3:0] counter_next;

  // SDA driver
  // always_comb begin
  //   case (state)
  //     kIdle:     i2c.sda = 'bZ;
  //     kTransmit: i2c.sda = data_reg[counter];
  //     kAck:      i2c.sda = 'bZ;
  //   endcase
  // end

  assign i2c.sda = (state == kTransmit) ? data_reg[counter] : 'bZ;

  // SCL driver
  // always_comb begin
  //   case (state)
  //     // kIdle:     i2c.scl = 1'bZ;
  //     kTransmit: i2c.scl = clk;
  //     kAck:      i2c.scl = clk;
  //   endcase
  // end

  assign i2c.scl = (state == kTransmit || state == kAck) ? clk : 'bZ;

  // Data Enable driver
  // Data can be only changed in certain states.
  //assign data_en = !(state == kIdle | (state == kAck & !ack));
  always_comb begin
    case (state)
      kIdle:     data_en = 'b0;
      kTransmit: data_en = 'b1;
      kAck:      data_en = ack;
    endcase
  end

  always @ (posedge clk) begin 
    case (state)

      kIdle: begin
        //if (! tx) begin
        //  data_reg <= data;
        //  state_next <= kTransmit;
        //end
      end

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

