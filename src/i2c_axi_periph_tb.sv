`timescale 1ns / 1ps

import axi_vip_pkg::*;
import design_axi_vip_axi_vip_0_0_pkg::*;

module i2c_axi_tb();

  localparam BASE_ADDR = 'h44A00000;
  localparam CTRL_ADDR = BASE_ADDR + 'h00;
  localparam ADDR_ADDR = BASE_ADDR + 'h04;
  localparam DATA_ADDR = BASE_ADDR + 'h08;

  bit aclk;
  bit aresetn;

  wire scl;
  wire sda;
  
  design_axi_vip_axi_vip_0_0_mst_t vip;
  xil_axi_prot_t prot = 0;
  xil_axi_resp_t resp;

  design_axi_vip design_axi_vip(
    .aclk(aclk),
    .aresetn(aresetn),

    .scl(scl),
    .sda(sda)
  );
  
  always #5ns aclk = !aclk;
  
  initial begin
    vip = new ("vip", design_axi_vip.axi_vip_0.inst.IF);
    
    vip.start_master();
  
    #50ns aresetn <= 'b1;
    
    #50ns;
    vip.AXI4LITE_WRITE_BURST(DATA_ADDR, prot, 32'h00000000, resp);  
  
    #50ns;
    vip.AXI4LITE_WRITE_BURST(ADDR_ADDR, prot, 32'h00000003, resp);  
  
    #500ns $finish;
  end

endmodule
