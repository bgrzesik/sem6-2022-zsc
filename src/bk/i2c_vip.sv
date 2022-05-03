`include "i2c_if.sv"

class I2CVip;

  virtual i2c_if i2c;
  logic sda_drive;

  function new (virtual i2c_if i2c);
    this.i2c = i2c;
    this.sda_drive = 1'bZ;
  endfunction
/*
  task start_bit ();
    $display("[%d] --- start bit begin", $time);
    if (! i2c.scl | ! i2c.sda) this.fail("Start: Both SDA & SCL should be high");

    @(negedge i2c.sda);
    if (! i2c.scl | i2c.sda) this.fail("Start: Start bit SCL high");
    $display("[%d] --- start bit mid", $time);

    @(negedge i2c.scl);
    if (i2c.scl | i2c.sda) this.fail("Start: Both SDA & SCL should be low");
    $display("[%d] --- start bit end", $time);
  endtask

  task stop_bit ();
    $display("[%d] --- stop bit begin", $time);
    // TODO uncomment?
    //if (i2c.scl | i2c.sda) this.fail("Stop: Both SDA & SCL should be low");

    @(posedge i2c.sda or posedge i2c.scl);
    if (! i2c.scl | i2c.sda) this.fail("Stop: SDA high");

    @(posedge i2c.sda or posedge i2c.scl);
    if (! i2c.scl | ! i2c.sda) this.fail("Stop: Both SDA & SCL should be high");
    $display("[%d] --- stop bit end", $time);
  endtask

  task read8(output logic [7:0] val);
    $display("[%d] --- byte begin", $time);
    foreach (val[idx]) begin
      @(posedge i2c.scl);

      $display("[%d] %d %d", $time, idx, i2c.sda);
      val[idx] = i2c.driver_cb.sda;

      @(negedge i2c.scl or i2c.sda);
      if (i2c.scl) this.fail("SDA changed on SCL high");
    end
    $display("[%d] %x", $time, val);
    $display("[%d] --- byte end", $time);
  endtask

  task write_bit(input logic val);
    $display("[%d] --- write bit begin", $time);

    i2c.driver_cb.sda <= val;
    @(posedge i2c.scl);
    i2c.driver_cb.sda <= 'bZ;
    @(negedge i2c.scl);

    $display("[%d] --- write bit end", $time);
  endtask

  task read_v1();
    byte val;
    $display("[%d] --- read begin", $time);

    this.start_bit();

    while (1) begin
      this.read8(val);
      this.write_bit('b0);

      $display("[%d] --- read pre", $time);
      @(posedge i2c.scl);
      $display("[%d] --- read tmp", $time);
      @(posedge i2c.sda or negedge i2c.scl);
      $display("[%d] --- read byte", $time);

      if (i2c.scl) break;
    end

    //this.stop_bit();
    $display("[%d] --- read end", $time);
  endtask

  task read_v2();
    byte bytes [];
    logic [0:7] by;


    @(negedge i2c.sda);
    @(negedge i2c.scl);

    @(posedge i2c.scl);

    by[7] = i2c.sda;

    while (1) begin
      for (int i = 6; i >= 0; i--) begin
        @(posedge i2c.scl);
        by[i] = i2c.sda;
      end

      $display("[%d] v2 byte = %x", $time, by);
      bytes = new [bytes.size() + 1](bytes);
      bytes[bytes.size() - 1] = by;

      @(negedge i2c.scl);
      i2c.driver_cb.sda <= 'b0;
      @(posedge i2c.scl);
      i2c.driver_cb.sda <= 'bZ;
      @(negedge i2c.scl);

      @(posedge i2c.scl);
      @(negedge i2c.scl or posedge i2c.sda);

      if (i2c.scl) break;

      by[7] = i2c.sda;
    end
  endtask
*/
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

  task read_v3(input int ack_count, output byte bytes []);
    event start_bit, stop_bit;
    logic [0:7] val; // reverse bit order (MSB goes first)
    // byte bytes[];

    bytes = new [0];

    fork
      detect_start(start_bit);
      detect_stop(stop_bit);
    join_none

    fork
      begin
        wait(start_bit.triggered);
        while (1) begin
          for (int i = 0; i < 8; i++) begin
            @(posedge i2c.scl);
            val[i] = i2c.sda;
          end

          $display("[%d] v3 byte = %h", $time, val);
          bytes = new [bytes.size() + 1](bytes);
          bytes[bytes.size() - 1] = val;

          @(negedge  i2c.scl);

          if (ack_count > 0)
            i2c.driver_cb.sda <= 'b0;
          else if (ack_count == 0)
            i2c.driver_cb.sda <= 'b1;
          else
            this.fail("Controller should stop");

          ack_count = ack_count - 1;

          @(posedge i2c.scl);
          i2c.driver_cb.sda <= 'bZ;
        end
      end

      wait(stop_bit.triggered);
    join_any;

    disable fork;
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
