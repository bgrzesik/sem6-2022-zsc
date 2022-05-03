
module i2c_tx (
    i2c_if.ctrl_tx i2c,

    input logic       clk,
    input logic       rstn,
    input logic       tx,

    input logic [7:0] data,

    output bit        data_en, // Data Enable, active on low
    output bit        ack_en,  // Ack Enable, active on low
    output bit        ack_s    // Ack State, ACK on low, NAK on high
  );

  typedef enum logic [0:4] {
    kIdle  = 0,
    kStart = 1,
    kTransmit = 2,
    kAck   = 3,
    kStop  = 4
  } state_t;

  state_t state, state_next;

  logic [7:0] data_reg;
  logic [3:0] counter;
  logic [3:0] counter_next;


  // SDA driver
  always_comb begin
    case (state)
      kIdle:  i2c.sda = 1'bZ;

      kStart: i2c.sda = counter == 4'd2;

      kTransmit: i2c.sda = data_reg[counter];

      kAck:   i2c.sda = 1'bZ;

      kStop:  i2c.sda = counter == 4'd0;
    endcase
  end

  // SCL driver
  always_comb begin
    case (state)
      kIdle:  i2c.scl = 1'bZ;

      kStart: i2c.scl = counter == 4'd2 | counter == 4'd1;

      kTransmit: i2c.scl = clk;

      kAck:   i2c.scl = clk;

      kStop:  i2c.scl = counter == 4'd1 | counter == 4'd0;
    endcase
  end

  // Data Enable driver
  // Data can be only changed in certain states.
  assign data_en = !(state == kStart | (state == kAck & !ack_s));

  always @ (posedge clk) begin 
    case (state)

      kIdle: begin
        ack_s <= 1'b1;
        ack_en <= 1'b1;

        data_reg <= 8'h00;
        counter_next <= 4'd2;
        if (!tx) state_next <= kStart;
      end

      kStart: begin
        counter_next <= counter - 4'd1;
      end

      kAck: begin
        ack_s <= i2c.sda ? 1'b1 : 1'b0;
        ack_en <= 1'b0;

        if (! i2c.sda) $display("[%d] ACK", $time);
        else $display("[%d] NAK", $time);
      end

      kStop: begin
        if (counter == 4'd0)
          state_next = kIdle;
        else
          counter_next <= counter - 4'd1;
      end

    endcase
  end

  always @ (negedge clk) begin 
    if (! rstn) begin
      state_next <= kIdle;
    end else begin
      case (state)

        kStart: begin
          if (counter == 4'd0) begin
            state_next <= kTransmit;
            data_reg <= data;
            counter_next <= 4'd7;
          end else begin
            counter_next <= counter - 4'd1;
          end
        end

        kTransmit: begin
          ack_en <= 1'b1;
          if (counter_next == 4'd0) state_next <= kAck;
          else counter_next <= counter_next - 1;
        end

        kAck: begin
          if (!ack_s & !tx) begin
            data_reg <= data;
            counter_next <= 4'd7;
            state_next <= kTransmit;
          end else begin
            counter_next <= 4'd2;
            state_next <= kStop;
          end
        end

        kStop: begin
          counter_next <= counter - 4'd1;
        end

      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;

    // ack_s = 1'b1;
    // ack_en = 1'b1;

    /* case (state)

      kIdle: begin
        ack_s = 1'b1;
        ack_en = 1'b1;
      end

      kStart: begin
      end

      kTransmit: begin
        ack_en = 1'b1;
      end

      kAck: begin
      end

      kStop: begin
        ack_en = 1'b1;
      end

    endcase */
  end

endmodule
