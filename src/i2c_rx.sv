
module i2c_rx (
    i2c_if.ctrl_rx i2c,

    input logic        clk,
    input logic        rstn,
    input logic        rx,

    output logic [7:0] data,
    output logic       data_rdy, // Data Ready, active on low

    output bit         ack_en,   // Ack Enable, active on low
    input logic        ack       // Ack input
  );

  typedef enum logic [0:4] {
    kIdle    = 0,
    kReceive = 1,
    kAck     = 2
  } state_t;

  state_t state, state_next;

  logic [0:7] data_reg;

  logic [3:0] counter;
  logic [3:0] counter_next;

  // SDA driver
  always_comb begin
    case (state)
      kAck:     i2c.sda = ack;
    endcase
  end;

  // SCL driver
  always_comb begin
    case (state)
      kIdle:    i2c.scl = 'bZ;
      kReceive: i2c.scl = clk;
      kAck:     i2c.scl = clk;
    endcase
  end;

  // Ack Enable driver
  always_comb begin
    case (state)
      kIdle:    ack_en = 'b1;
      kReceive: ack_en = 'b1;
      kAck:     ack_en = 'b0;
    endcase
  end;

  // Data Ready driver
  always_comb begin
    case (state)
      kIdle:    data_rdy = 'b1;
      kReceive: data_rdy = 'b1;
      kAck:     data_rdy = 'b0;
    endcase
  end;

  always @ (posedge clk) begin
    case (state)

      kReceive: begin
        data_reg[counter] <= i2c.sda;
      end

    endcase
  end

  always @ (negedge clk) begin
    if (! rstn) begin
      state_next <= kIdle;
      counter_next <= 8'd7;
      data_reg <= 8'd0;

    end else begin
      case (state)

        kIdle: begin
          counter_next <= 8'd7;
          data_reg <= 8'h00;

          if (!rx) state_next <= kReceive;
        end

        kReceive: begin
          if (counter == 4'd0) begin
            counter_next <= 8'd7;
            state_next <= kAck;
            data <= data_reg;

            $display("[%d] read %h", $time, data_reg);
          end else begin
            counter_next <= counter - 1;
          end
        end

        kAck: begin
          if (!ack & !rx) begin
            counter_next <= 4'd7;
            state_next <= kReceive;
          end else begin
            state_next <= kIdle;
          end

          data_reg <= 'h00;
        end

      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;
  end


endmodule

