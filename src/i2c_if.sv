
interface i2c_if;
  logic sda;
  logic scl;

  // Both need SDA's input and output for ACK
  modport ctrl_tx (
    inout sda,
    output scl
  );
  modport ctrl_rx (
    inout sda,
    output scl
  );

  clocking driver_cb @ (negedge scl);
    default input #1step output #0step;
    inout sda;
    inout scl;
  endclocking

endinterface
