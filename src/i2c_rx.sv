
module i2c_rx (
    i2c_if.ctrl_rx i2c,

     input wire        clk,
     input wire        rstn,
     input wire        rx,

    output bit   [7:0] data,
    output wire        data_rdy, // Data Ready, active on low

    output wire        ack_en,   // Ack Enable, active on low
     input wire        ack       // Ack input
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

  // SDA driver
  assign i2c.sda = (state == kAck) ? ack : 'bZ;

  // SCL driver
  assign i2c.scl = (state == kReceive || state == kAck) ? clk : 'bZ;

  // Ack Enable driver
  assign ack_en = !(state == kAck);

  // Data Ready driver
  assign data_rdy = !(state == kAck);

  always @ (posedge clk) begin
    case (state)

      kReceive: begin
        data_reg[counter] <= i2c.sda;
      end

    endcase
  end

  always @ (negedge clk) begin
    if (! rstn | state == kIdle) begin
      counter_next <= 8'd7;
      data_reg <= 8'h00;
      data <= 8'h00;

      if (!rx) 
        state_next <= kReceive;
      else
        state_next <= kIdle;

    end else begin
      case (state)

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

