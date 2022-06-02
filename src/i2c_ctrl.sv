
module i2c_ctrl #(
  parameter CLK_FREQ=50_000_000,
  parameter CLK_DIV=CLK_FREQ / 100_000,
  parameter DIV_LEN = 16
) (
    output wire        i2c_sda_i,
    output wire        i2c_sda_t,
     input wire        i2c_sda_o,

    output wire        i2c_scl_i,
    output wire        i2c_scl_t,
     input wire        i2c_scl_o,

     input wire        clk,
     input wire        rstn,
     input wire        feed,  // Has more data to transmit/receive

     input wire        rx_ack,
    output wire        tx_ack,
    output wire        busy, // Low on next rx/tx byte

     input wire  [7:0] addr,
     input wire  [7:0] tx_data,
    output wire  [7:0] rx_data,

    output wire        idle,

    output wire  [7:0] dbg_state
  );

  localparam CLK_HIGH = (4 * CLK_DIV) / 5;
  localparam START_STOP_DUR = 3 * CLK_DIV / 2;

  typedef enum bit [0:5] {
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

  assign dbg_state = state;

  assign idle = !(state == kIdle);

  assign busy = !(state == kStart
                | state == kAddressAck
                | state == kTransmitAck
                | state == kReceiveAck
                | state == kStop);

  // SCL driver
  logic clk_scl_i;
  logic clk_scl_t;
  logic clk_scl_o;

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
    .i2c_scl_i(clk_scl_i),
    .i2c_scl_t(clk_scl_t),
    .i2c_scl_o(clk_scl_o),

    .rstn(rstn),
    .clk(clk),
    .en(scl_en),
    .counter(clk_counter) // TODO get rid of, everything should be able to 'switch' on SCL low
  );

  bit [15:0] counter;
  bit [15:0] counter_next;

  logic       tx_sda_i;
  logic       tx_sda_t;
  logic       tx_sda_o;

  logic       tx_en;
  logic       tx_rstn;
  logic       tx_data_en;
  logic       tx_ack_en;
  logic [7:0] tx_data_in;

  i2c_tx #(
    .CLK_DIV(CLK_DIV),
    .DIV_LEN(DIV_LEN)
  ) i2c_tx (
    .i2c_sda_i(tx_sda_i),
    .i2c_sda_t(tx_sda_t),
    .i2c_sda_o(tx_sda_o),
    .i2c_scl_o(clk_scl_i),

    .clk(clk),
    .rstn(tx_rstn),
    .tx(tx_en),

    .data(tx_data_in),
    .clk_counter(clk_counter),

    .data_en(tx_data_en),
    .ack(tx_ack),
    .ack_en(tx_ack_en)
  );

  always_comb begin
    tx_en = 'b1;
    tx_rstn = 'b0;
    tx_data_in = 'hFF;

    if (rstn) begin
      case (state) 
        kAddress: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data_in = addr;
        end
        kAddressAck: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data_in = tx_data; // Provide data early
        end
        kTransmit: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data_in = tx_data;
        end
        kTransmitAck: begin
          tx_en = 'b0;
          tx_rstn = 'b1;
          tx_data_in = tx_data;
        end
      endcase
    end
  end

  logic       rx_sda_i;
  logic       rx_sda_t;
  logic       rx_sda_o;

  logic       rx_en;
  logic       rx_rstn;
  logic       rx_data_rdy;
  logic       rx_ack_en;

  i2c_rx #( 
    .CLK_FREQ(CLK_FREQ),
    .CLK_DIV(CLK_DIV),
    .DIV_LEN(DIV_LEN)
  ) i2c_rx (
    .i2c_sda_i(rx_sda_i),
    .i2c_sda_t(rx_sda_t),
    .i2c_sda_o(rx_sda_o),
    .i2c_scl_o(clk_scl_i),

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

  logic sda_driver;
  assign i2c_sda_t = (state != kStart) & tx_sda_t & rx_sda_t & (state != kStop);
  assign i2c_sda_i = (state == kStart)       ? sda_driver :
                     (state == kAddress)     ? tx_sda_i :
                     (state == kAddressAck)  ? tx_sda_i :
                     (state == kTransmit)    ? tx_sda_i :
                     (state == kTransmitAck) ? tx_sda_i :
                     (state == kReceive)     ? rx_sda_i :
                     (state == kReceiveAck)  ? rx_sda_i :
                     (state == kStop)        ? sda_driver : 1;

  assign tx_sda_o = i2c_sda_o;
  assign rx_sda_o = i2c_sda_o;

  logic scl_driver;
  assign i2c_scl_t = (state != kStart) & clk_scl_t & (state != kStop);
  assign i2c_scl_i = (state == kStart)       ? scl_driver :
                     (state == kAddress)     ? clk_scl_i :
                     (state == kAddressAck)  ? clk_scl_i :
                     (state == kTransmit)    ? clk_scl_i :
                     (state == kTransmitAck) ? clk_scl_i :
                     (state == kReceive)     ? clk_scl_i :
                     (state == kReceiveAck)  ? clk_scl_i :
                     (state == kStop)        ? scl_driver: 1;

  assign clk_scl_o = i2c_scl_o;

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
