
interface i2c_sda_if;
  wire i;
  wire o;
  wire t; // 1 -> IO = Z; 0 -> IO = I
endinterface

interface i2c_scl_if;
  wire i;
  wire o;
  wire t; // 1 -> IO = Z; 0 -> IO = I
endinterface

interface i2c_if;
  wire sda;
  wire scl;

  // wire sda_i;
  // wire sda_o;
  // wire sda_t; // 1 -> IO = Z; 0 -> IO = I

  // wire scl_i;
  // wire scl_o;
  // wire scl_t; // 1 -> IO = Z; 0 -> IO = I

  clocking driver_cb @ (negedge scl);
    default input #1step output #0step;
    inout sda;
    inout scl;
   endclocking

endinterface
