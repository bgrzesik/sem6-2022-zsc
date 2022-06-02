
interface i2c_if;
  wire sda;
  wire scl;

  clocking driver_cb @ (negedge scl);
    default input #1step output #0step;
    inout sda;
    inout scl;
  endclocking

endinterface
