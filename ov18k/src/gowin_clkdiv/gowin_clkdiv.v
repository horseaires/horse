//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//GOWIN Version: V1.9.8
//Part Number: GW2A-LV18PG484C8/I7
//Device: GW2A-18
//Created Time: Wed Oct 27 00:37:01 2021

module Gowin_CLKDIV (clkout, hclkin, resetn, calib);

output clkout;
input hclkin;
input resetn;
input calib;

CLKDIV clkdiv_inst (
    .CLKOUT(clkout),
    .HCLKIN(hclkin),
    .RESETN(resetn),
    .CALIB(calib)
);

defparam clkdiv_inst.DIV_MODE = "5";
defparam clkdiv_inst.GSREN = "false";

endmodule //Gowin_CLKDIV
