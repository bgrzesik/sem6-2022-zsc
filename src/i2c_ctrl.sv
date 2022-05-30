
module i2c_ctrl #(
  parameter CLK_FREQ=50_000_000,
  parameter CLK_DIV=CLK_FREQ / 100_000,
  parameter DIV_LEN = 16
) (
    i2c_if i2c,

     input wire        clk,
     input wire        rstn,
     input wire        feed,  // Has more data to transmit/receive

     input wire        rx_ack,
    output wire        tx_ack,
    output wire        busy, // Low on next rx/tx byte

     input wire  [7:0] addr,
     inout wire  [7:0] data,

    output wire        idle
  );

  localparam CLK_HIGH = (4 * CLK_DIV) / 5;
  localparam START_STOP_DUR = 3 * CLK_DIV / 2;

  typedef enum bit [0:8] {
    kIdle        = 0,

    kStart       = 1,

    kAddress     = 2,
    kAddressAck  = 3,

    kTransmit    = 4,
    kTransmitAck = 5,

    kReceive     = 6,
    kReceiveAck  = 7,

    kStop        = 8
  } state_t;

  state_t state, state_next;

  assign idle = !(state == kIdle);

  assign busy = !(state == kStart
                | state == kAddressAck
                | state == kTransmitAck
                | state == kReceiveAck
                | state == kStop);

  // SCL driver
  wire [DIV_LEN - 1:0] clk_counter;
  wire scl_en;
  assign scl_en = !(state == kAddress
                  | state == kAddressAck
                  | state == kTransmit
                  | state == kTransmitAck
                  | state == kReceive
                  | state == kReceiveAck);

  i2c_clk_driver #(
    .CLK_DIV(CLK_DIV),
    .DIV_LEN(DIV_LEN)
  ) i2c_clk_driver (
    .rstn(rstn),
    .clk(clk),
    .en(scl_en),
    .clk_out(i2c.scl),
    .counter(clk_counter) // TODO get rid of, everything should be able to 'switch' on SCL low
  );

  bit [7:0] counter;
  bit [7:0] counter_next;

  logic       tx_en;
  logic       tx_rstn;
  logic       tx_data_en;
  logic       tx_ack_en;
  logic [7:0] tx_data;

  i2c_tx #(
    .CLK_FREQ(CLK_FREQ),
    .CLK_DIV(CLK_DIV),
    .DIV_LEN(DIV_LEN)
  ) i2c_tx (
    .i2c(i2c.ctrl_tx),

    .clk(clk),
    .rstn(tx_rstn),
    .tx(tx_en),

    .data(tx_data),
    .clk_counter(clk_counter),

    .data_en(tx_data_en),
    .ack(tx_ack),
    .ack_en(tx_ack_en)
  );

  always_comb begin
    tx_en = 'b1;
    tx_rstn = 'b0;
    tx_data = 'hFF;

    if (rstn) begin
      case (state) 
        kAddress: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data = addr;
        end
        kAddressAck: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data = data; // Provide data early
        end
        kTransmit: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data = data;
        end
        kTransmitAck: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data = data;
        end
      endcase
    end
  end

  logic       rx_en;
  logic       rx_rstn;
  logic       rx_data_rdy;
  logic       rx_ack_en;
  logic [7:0] rx_data;

  i2c_rx #( 
    .CLK_FREQ(CLK_FREQ),
    .CLK_DIV(CLK_DIV),
    .DIV_LEN(DIV_LEN)
  ) i2c_rx (
    .i2c(i2c.ctrl_rx),

    .clk(clk),
    .rstn(rx_rstn),
    .rx(rx_en),
    .clk_counter(clk_counter),

    .data(rx_data),

    .data_rdy(rx_data_rdy),
    .ack(rx_ack),
    .ack_en(rx_ack_en)
  );

  always_comb begin
    rx_en = 'b1;
    rx_rstn = 'b0;
    //rx_ack = 'b1;

    if (rstn) begin
      case (state) 
        kReceive: begin
          rx_en = 'b0;
          rx_rstn = 'b1;
          //rx_ack = 'b1;
        end
        kReceiveAck: begin
          rx_en = 'b0;
          rx_rstn = 'b1;
          //rx_ack = 'b0; // TODO
        end
      endcase
    end
  end

  assign data = state == kReceiveAck ? rx_data : 'hZZ;

  logic sda_driver;
  assign i2c.sda = ((state == kStart | state == kStop) & !sda_driver) ? 'b0 : 'bZ;

  logic scl_driver;
  assign i2c.scl = ((state == kStart | state == kStop) & !scl_driver) ? 'b0 : 'bZ;

  always_comb begin
    sda_driver = 'b1;
    scl_driver = 'b1;

    if (rstn) begin
      case (state)
        kStart: begin
          sda_driver = counter_next < 1 * START_STOP_DUR / 3;
          scl_driver = counter_next < 2 * START_STOP_DUR / 3;
        end
        kStop: begin
          sda_driver = counter_next > 2 * START_STOP_DUR / 3;
          scl_driver = counter_next > 1 * START_STOP_DUR / 3;
        end
      endcase
    end
  end

  always @ (negedge clk) begin
    if (! rstn | state == kIdle) begin
      counter_next <= 'd0;

      if (rstn & !feed)
        state_next <= kStart;
      else
        state_next <= kIdle;

    end else begin
      case (state)

        kStart: begin
          if (counter >= START_STOP_DUR - 1) begin
            state_next <= kAddress;
            counter_next <= 'd0;
          end else begin
            counter_next <= counter + 1;
          end
        end

        kAddress: begin
          if (!tx_ack_en) state_next <= kAddressAck;
        end

        kAddressAck: begin
          if (tx_ack_en) begin // TODO
            if (!tx_ack & !addr[0]) // TODO & !feed
              state_next <= kTransmit;
            else if (!tx_ack & addr[0]) // TODO & !feed
              state_next <= kReceive;
            else
              state_next <= kStop;
          end
        end

        kTransmit: begin
          if (!tx_ack_en) state_next <= kTransmitAck;
        end

        kTransmitAck: begin
          if (tx_ack_en) begin
            if (!tx_ack & !feed)
              state_next <= kTransmit;
            else
              state_next <= kStop;
          end
        end

        kReceive: begin
          if (!rx_ack_en) state_next <= kReceiveAck;
        end

        kReceiveAck: begin
          if (rx_ack_en) begin
            if (!rx_ack & !feed)
              state_next <= kReceive;
            else
              state_next <= kStop;
          end
        end

        kStop: begin
          if (counter >= START_STOP_DUR - 1) begin
            state_next <= kIdle;
            counter_next <= 'd0;
          end else begin
            counter_next <= counter + 1;
          end
        end

      endcase
    end
  end

  always_comb begin
    state = state_next;
    counter = counter_next;
  end;

endmodule
