`include "i2c_if.sv"

class I2CVip;

  virtual i2c_if i2c;
  logic sda_drive;

  function new (virtual i2c_if i2c);
    this.i2c = i2c;
    this.sda_drive = 1'bZ;
  endfunction

  task detect_start(ref event start_bit);
    while(1) begin
      @(negedge i2c.sda);
      if (! i2c.scl) continue;

      @(negedge i2c.scl);
      if (i2c.sda) continue;

      $display("[%d] start", $time);
      -> start_bit;
      break;
    end
  endtask

  task detect_stop(ref event stop_bit);
    while (1) begin
      @(posedge i2c.scl);
      if (i2c.sda) continue;

      @(posedge i2c.sda);
      if (! i2c.scl) continue;

      $display("[%d] stop", $time);
      -> stop_bit;
      break;
    end
  endtask

  task read(input int ack_count, output byte bytes []);
    logic [0:7] val; // reverse bit order (MSB goes first)
    bytes = new [0];

    while (1) begin
      for (int i = 0; i < 8; i++) begin
        @(posedge i2c.scl);
        val[i] = i2c.sda;
      end

      $display("[%d] v3 byte = %h", $time, val);
      bytes = new [bytes.size() + 1](bytes);
      bytes[bytes.size() - 1] = val;

      @(negedge i2c.scl);

      $display("[%d] -------- ", $time);

      //#1;

      if (ack_count > 0)
        i2c.sda <= 'b0;
      else if (ack_count == 0)
        i2c.sda <= 'b1;
      else
        this.fail("Controller should stop");

      ack_count = ack_count - 1;
      if (ack_count == 0) break;

      @(posedge i2c.scl);
      i2c.driver_cb.sda <= 'bZ;
    end
  endtask

  task write(input int ack_count, input byte bytes []);
    logic [7:0] by;

    foreach (bytes[i]) begin
      by = bytes[i];

      $display("[%d] writing %h", $time, by);

      for (int j = 0; j < 8; j++) begin
        @(negedge i2c.scl);
        i2c.sda = by[j];
      end

      @(negedge i2c.scl);
      i2c.sda <= 'bZ;
      @(posedge i2c.scl);

      if (i2c.sda) begin
        $display("[%d] got NAK", $time);
        break;
      end else begin
        $display("[%d] got ACK", $time);
      end;

      ack_count = ack_count - 1;
      if (ack_count == 0) break;
    end

    if (ack_count != 'd0) this.fail("ACK count didn't match");
  endtask

  task fail(string msg);
    $display("[%d] I2C verification failed: %s", $time, msg);
    //$finish;
  endtask

endclass