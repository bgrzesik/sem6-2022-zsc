


module i2c_ctrl (
    i2c_if i2c,

     input wire        clk,
     input wire        rstn,
     input wire        en,

     input wire  [7:0] addr,
     inout wire  [7:0] data,

    output wire        busy,
    output wire        data_rdy
  );

  typedef enum bit [0:8] {
    kIdle     = 0,
    kStart    = 1,
    kAddress  = 2,

    kTransmit = 3,
    kReceive  = 4,

    kAck      = 5, // TODO rethink

    kStop     = 6
  } state_t;

  state_t state, state_next;

  bit [7:0] counter;
  bit [7:0] counter_next;

  logic       tx_en;
  logic       tx_rstn;
  logic       tx_data_en;
  logic       tx_ack_en;
  logic       tx_ack;
  logic [7:0] tx_data;

  assign busy = !(state == kIdle);

  i2c_tx i2c_tx (
    .i2c(i2c.ctrl_tx),

    .clk(clk),
    .rstn(tx_rstn),
    .tx(tx_en),

    .data(tx_data),

    .data_en(tx_data_en),
    .ack(tx_ack),
    .ack_en(tx_ack_en)
  );

  always_comb begin
    if (! rstn | state == kIdle) begin
      tx_en = 'b1;
      tx_rstn = 'b0;
      tx_data = 'hFF;

    end else begin
      case (state) 
        kStart: begin
          tx_rstn = 'b1;
          tx_data = addr;
          if (counter == 'd2)
            tx_en = 'b0;
        end
        kAddress: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data = addr;
        end
        kTransmit: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data = data;
        end
        kReceive: begin
          tx_en = 'b1;
          tx_rstn = 'b0;
          tx_data = 'hFF;
        end
        kStop: begin
          tx_en = 'b1;
          tx_rstn = 'b0;
          tx_data = 'hFF;
        end
      endcase
    end
  end

  always @ (negedge tx_ack_en) begin
    case (state)
      kAddress: begin
        if (! tx_ack) begin
          if (! addr[0])
            state_next <= kTransmit;
          else
            state_next <= kReceive;

        end else begin
          state_next <= kAck; // TODO
        end
      end

      kTransmit: begin
        if (! tx_ack)
          state_next <= kStop;
        else
          state_next <= kAck; // TODO
      end
    endcase
  end

  logic       rx_en;
  logic       rx_rstn;
  logic       rx_data_rdy;
  logic       rx_ack_en;
  logic       rx_ack;
  logic [7:0] rx_data;

  i2c_rx i2c_rx (
    .i2c(i2c.ctrl_rx),

    .clk(clk),
    .rstn(rx_rstn),
    .rx(rx_en),

    .data(rx_data),

    .data_rdy(rx_data_rdy),
    .ack(rx_ack),
    .ack_en(rx_ack_en)
  );

  always_comb begin
    if (! rstn | state == kIdle) begin
      rx_en = 'b1;
      rx_rstn = 'b0;
      rx_ack = 'b1;
    end else begin
      case (state) 
        kAddress: begin
          rx_en = 'b1;
          rx_rstn = 'b0;
          rx_ack = 'b1;
        end
        kTransmit: begin
          rx_en = 'b1;
          rx_rstn = 'b0;
          rx_ack = 'b1;
        end
        kReceive: begin
          rx_en = 'b0;
          rx_rstn = 'b1;
          rx_ack = 'b1;
        end
        kAck: begin
          rx_en = 'b1;
          rx_rstn = 'b0;
          rx_ack = 'b0; // TODO
        end
        kStop: begin
          rx_en = 'b1;
          rx_rstn = 'b0;
          rx_ack = 'b0; // TODO
        end
      endcase
    end
  end

  always @ (negedge rx_ack_en) begin
    if (! rx_ack) begin
      state_next = kStop;
    end else begin
      state_next = kAck;
    end
  end

  assign data = state == kAck ? rx_data : 'hZZ;
  assign data_rdy = !(addr[0] & state == kAck & ! rx_data_rdy);

  assign i2c.sda =
    (state == kStart | state == kStop) ?
      ((state == kStart) ? counter == 'd0 : counter == 'd2) : 'bZ;

  assign i2c.scl =
    (state == kStart | state == kStop) ?
      ((state == kStart) ? (counter == 'd0 | counter == 'd1) : (counter == 'd1 | counter == 'd2)) : 'bZ;

  always @ (posedge clk) begin
    case (state)

      kIdle: begin
        if (rstn) state_next <= kStart;

      end

      kStart: begin
        counter_next = counter + 1;
      end

      kStop: begin
        counter_next = counter + 1;

        if (counter == 'd2)
          state_next <= kIdle;
      end

    endcase
  end

  always @ (negedge clk) begin
    if (! rstn | state == kIdle) begin
      state_next <= kIdle;
      counter_next <= 'd0;

    end else begin
      case (state)

        kStart: begin
          counter_next <= counter + 1;

          if (counter == 'd2)
            state_next <= kAddress;
        end

        kAck: begin
          state_next <= kStop; // TODO
          counter_next <= 'd0;
        end

        kStop: begin
          counter_next <= counter + 1;
        end

      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;
  end;

endmodule;
