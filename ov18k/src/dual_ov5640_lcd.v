module dual_ov5640_lcd(    
    input         sys_clk    ,  //系统时钟
    input         sys_rst_n  ,  //系统复位，低电平有效
    //摄像头0 
    input         cam0_pclk  ,  //cmos 数据像素时钟
    input         cam0_vsync ,  //cmos 场同步信号
    input         cam0_href  ,  //cmos 行同步信号
    input  [7:0]  cam0_data  ,  //cmos 数据  
    output        cam0_rst_n ,  //cmos 复位信号，低电平有效
    output        cam0_scl   ,  //cmos SCCB_SCL线
    inout         cam0_sda   ,  //cmos SCCB_SDA线
    
    //摄像头1 
    input         cam1_pclk  ,  //cmos 数据像素时钟
    input         cam1_vsync ,  //cmos 场同步信号
    input         cam1_href  ,  //cmos 行同步信号
    input  [7:0]  cam1_data  ,  //cmos 数据  
    output        cam1_rst_n ,  //cmos 复位信号，低电平有效
    output        cam1_scl   ,  //cmos SCCB_SCL线
    inout         cam1_sda   ,  //cmos SCCB_SDA线    

    //HDMI
	output	   		  O_tmds_clk_p      ,
	output	   		  O_tmds_clk_n      ,
	output	   [2:0]  O_tmds_data_p     ,//{r,g,b}
	output	   [2:0]  O_tmds_data_n     ,

    //SDRAM 
	output	   [13:0] O_ddr_addr      ,
	output	   [2:0]  O_ddr_ba        ,
	output 	   	      O_ddr_cs_n      ,
	output 	   	      O_ddr_ras_n     ,
	output 	   	      O_ddr_cas_n     ,
	output 	   	      O_ddr_we_n      ,
	output 	   	      O_ddr_clk       ,
	output 	   	      O_ddr_clk_n     ,
	output 	   	      O_ddr_cke       ,
	output 	   	      O_ddr_odt       ,
	output 	   	      O_ddr_reset_n   ,
	output 	   [1:0]  O_ddr_dqm       ,
	inout  	   [15:0] IO_ddr_dq       ,
	inout  	   [1:0]  IO_ddr_dqs      ,
	inout  	   [1:0]  IO_ddr_dqs_n       
    );

//=========================================================
//SRAM parameters
parameter IMAGE_SIZE          = 28'h080_0000;//--8MB,byte address  //frame base address
parameter BURST_WRITE_LENGTH  = 1024;  //bytes
parameter BURST_READ_LENGTH   = 1024;  //bytes
parameter ADDR_WIDTH          = 28;    //存储单元是byte，总容量=2^27*16bit = 2Gbit,增加1位rank地址，{rank[0],bank[2:0],row[13:0],cloumn[9:0]}
parameter DATA_WIDTH          = 128;   //与生成DDR3IP有关，此ddr3 2Gbit, x16， 时钟比例1:4 ，则固定128bit
parameter DQ_WIDTH            = 16;
parameter VIDEO_WIDTH	      = 16;  

//wire define
wire        clk_100m       ;  //100mhz时钟,iic
wire        locked         ;
wire        rst_n          ;
                    
wire        cam0_init_done ;
wire        cam1_init_done ;
                    
//memory interface
wire                   cmd_ready          ;
wire[2:0]              cmd                ;
wire                   cmd_en             ;
wire[5:0]              app_burst_number   ;
wire[ADDR_WIDTH-1:0]   addr               ;
wire                   wr_data_rdy        ;
wire                   wr_data_en         ;//
wire                   wr_data_end        ;//
wire[DATA_WIDTH-1:0]   wr_data            ;   
wire[DATA_WIDTH/8-1:0] wr_data_mask       ;   
wire                   rd_data_valid      ;  
wire                   rd_data_end        ;//unused 
wire[DATA_WIDTH-1:0]   rd_data            ;   
wire                   init_calib_complete;
wire                   dma_clk  ;  

//memory interface dual
wire                   cmd_ready_dual          ;
wire[2:0]              cmd_dual                ;
wire                   cmd_en_dual             ;
wire[5:0]              app_burst_number_dual   ;
wire[ADDR_WIDTH-1:0]   addr_dual               ;
wire                   wr_data_rdy_dual        ;
wire                   wr_data_en_dual         ;//
wire                   wr_data_end_dual        ;//
wire[DATA_WIDTH-1:0]   wr_data_dual            ;   
wire[DATA_WIDTH/8-1:0] wr_data_mask_dual       ;   
wire                   rd_data_valid_dual      ;  
wire                   rd_data_end_dual        ;//unused 
wire[DATA_WIDTH-1:0]   rd_data_dual            ;   

wire [12:0] cmos0_h_pixel  = 13'd640 ;  //CMOS水平方向像素个数 
wire [12:0] cmos0_v_pixel  = 13'd360  ;  //CMOS垂直方向像素个数
wire [12:0] cmos0_total_h_pixel = 13'd2570 ;  //水平总像素大小
wire [12:0] cmos0_total_v_pixel = 13'd980  ;  //垂直总像素大小

wire [12:0] cmos1_h_pixel  = 13'd640 ;  //CMOS水平方向像素个数 
wire [12:0] cmos1_v_pixel  = 13'd360  ;  //CMOS垂直方向像素个数
wire [12:0] cmos1_total_h_pixel = 13'd2570 ;  //水平总像素大小
wire [12:0] cmos1_total_v_pixel = 13'd980  ;  //垂直总像素大小

//syn_code
wire                   syn_off0_re;  // ofifo read enable signal
wire                   syn_off0_vs;
wire                   syn_off0_hs;
                       
wire                   off0_syn_de  ;
wire [VIDEO_WIDTH-1:0] off0_syn_data;
wire                   vout0fifo_empty;

//test pattern
wire        tp0_vs_in  ;
wire        tp0_hs_in  ;
wire        tp0_de_in ;
wire [ 7:0] tp0_data_r;
wire [ 7:0] tp0_data_g;
wire [ 7:0] tp0_data_b;

reg         vs_r;
reg  [9:0]  cnt_vs;


//rgb data
wire        rgb_vs     ;
wire        rgb_hs     ;
wire        rgb_de     ;
wire [23:0] rgb_data   ;  

//HDMI4 TX
wire pix_clk/*synthesis syn_keep=1*/;
wire serial_clk;

wire pll_lock;

wire hdmi4_rst_n;

//-------------------------
//frame buffer in
wire                   ch0_vfb_clk_in ;
wire                   ch0_vfb_vs_in  ;
wire                   ch0_vfb_de_in  ;
wire [VIDEO_WIDTH-1:0] ch0_vfb_data_in;  
//==================================================
//cmos
wire                   cmos0_frame_valid;
wire [15:0]            cmos0_frame_data;
wire                   cmos1_frame_valid;
wire [15:0]            cmos1_frame_data;

assign  rst_n = sys_rst_n & locked;

cmos_rPLL u_cmos_rPLL(
    .clkout             (clk_100m   ), //output clkout
    .lock               (locked     ), //output lock
    .reset              (~sys_rst_n ), //input reset
    .clkin              (sys_clk    )  //input clkin
);

//OV5640 0摄像头驱动,左边的
wire        cmos0_frame_vsync;
wire        cmos0_frame_href;
ov5640_dri u0_ov5640_dri(
    .clk               (clk_100m),
    .rst_n             (rst_n),

    .cam_pclk          (cam0_pclk ),
    .cam_vsync         (cam0_vsync),
    .cam_href          (cam0_href ),
    .cam_data          (cam0_data ),
    .cam_rst_n         (cam0_rst_n),
    .cam_scl           (cam0_scl  ),
    .cam_sda           (cam0_sda  ),
    
    .capture_start     (init_calib_complete),
    .cmos_h_pixel      (cmos0_h_pixel[12:1]),
    .cmos_v_pixel      (cmos0_v_pixel),
    .total_h_pixel     (cmos0_total_h_pixel),
    .total_v_pixel     (cmos0_total_v_pixel),
   

    .cmos_frame_vsync  (cmos0_frame_vsync),
    .cmos_frame_href   (cmos0_frame_href),
    .cmos_frame_valid  (cmos0_frame_valid),
    .cmos_frame_data   (cmos0_frame_data)
    );
    
//OV5640 1摄像头驱动，右边的
wire        cmos1_frame_vsync;
wire        cmos1_frame_href;
ov5640_dri u1_ov5640_dri(
    .clk               (clk_100m),
    .rst_n             (rst_n),

    .cam_pclk          (cam1_pclk ),
    .cam_vsync         (cam1_vsync),
    .cam_href          (cam1_href ),
    .cam_data          (cam1_data ),
    .cam_rst_n         (cam1_rst_n),
    .cam_scl           (cam1_scl  ),
    .cam_sda           (cam1_sda  ),
    
    .capture_start     (init_calib_complete),
    .cmos_h_pixel      (cmos1_h_pixel[12:1]),
    .cmos_v_pixel      (cmos1_v_pixel),
    .total_h_pixel     (cmos1_total_h_pixel),
    .total_v_pixel     (cmos1_total_v_pixel),
   

    .cmos_frame_vsync  (cmos1_frame_vsync),
    .cmos_frame_href   (cmos1_frame_href),
    .cmos_frame_valid  (cmos1_frame_valid),
    .cmos_frame_data   (cmos1_frame_data)
    );    

//assign ch0_vfb_clk_in  = cam1_pclk;
//assign ch0_vfb_vs_in   = cmos1_frame_vsync;
//assign ch0_vfb_de_in   = cmos1_frame_href;
//assign ch0_vfb_data_in = cmos1_frame_data;

cmos_add u_cmos_add(
    .sys_rst_n          (rst_n),

    .cmos0_pclk         (cam0_pclk),
    .cmos0_href         (cmos0_frame_href),
    .cmos0_data         (cmos0_frame_data),
    .cmos0_vsync        (cam0_vsync),

    .cmos1_pclk         (cam1_pclk),
    .cmos1_href         (cmos1_frame_href),
    .cmos1_data         (cmos1_frame_data),
    .cmos1_vsync        (cam1_vsync),

    .pixel_vsync        (ch0_vfb_vs_in),
    .pixel_href         (ch0_vfb_de_in),
    .pixel_data         (ch0_vfb_data_in)
);

Video_Frame_Buffer_Top Video_Frame_Buffer(
    .I_rst_n            (init_calib_complete), //input I_rst_n
    .I_dma_clk          (dma_clk            ), //input I_dma_clk
    .I_wr_halt          (1'd0               ), //input [0:0] I_wr_halt
    .I_rd_halt          (1'd0               ), //input [0:0] I_rd_halt
	// video data input    
    .I_vin0_clk         (cam0_pclk          ), //input I_vin0_clk
    .I_vin0_vs_n        (~ch0_vfb_vs_in     ), //input I_vin0_vs_n
    .I_vin0_de          (ch0_vfb_de_in      ), //input I_vin0_de
    .I_vin0_data        (ch0_vfb_data_in    ), //input [15:0] I_vin0_data
	// video data output
    .I_vout0_clk        (pix_clk            ), //input I_vout0_clk
    .I_vout0_vs_n       (~syn_off0_vs       ), //input I_vout0_vs_n
    .I_vout0_de         (syn_off0_re        ), //input I_vout0_de
    .O_vout0_den        (off0_syn_de        ), //output O_vout0_den
    .O_vout0_data       (off0_syn_data      ), //output [15:0] O_vout0_data
    .O_vout0_fifo_empty (vout0fifo_empty    ), //output O_vout0_fifo_empty
	// ddr write request
    .I_cmd_ready        (cmd_ready          ), //input I_cmd_ready
    .O_cmd              (cmd                ), //output [2:0] O_cmd
    .O_cmd_en           (cmd_en             ), //output O_cmd_en
    .O_app_burst_number (app_burst_number   ), //output [5:0] O_app_burst_number
    .O_addr             (addr               ), //output [27:0] O_addrh
    .I_wr_data_rdy      (wr_data_rdy        ), //input I_wr_data_rdy
    .O_wr_data_en       (wr_data_en         ), //output O_wr_data_en
    .O_wr_data_end      (wr_data_end        ), //output O_wr_data_end
    .O_wr_data          (wr_data            ), //output [127:0] O_wr_data
    .O_wr_data_mask     (wr_data_mask       ), //output [15:0] O_wr_data_mask
    .I_rd_data_valid    (rd_data_valid      ), //input I_rd_data_valid
    .I_rd_data_end      (rd_data_end        ), //input I_rd_data_end
    .I_rd_data          (rd_data            ), //input [127:0] I_rd_data
    .I_init_calib_complete(init_calib_complete) //input I_init_calib_complete
);

wire    clk_ddr_200MHz;
wire    ddr_lock;

//ddr锁相环，clk ratio 1:4
ddr_rPLL pll_ddr3(
    .clkout             (clk_ddr_200MHz     ), //output clkout
    .lock               (ddr_lock           ), //output lock
    .reset              (~sys_rst_n         ), //input reset
    .clkin              (sys_clk            )  //input clkin
);

DDR3_Memory_Interface_Top DDR3_MIG(
    .memory_clk         (clk_ddr_200MHz     ), //input memory_clk
    .clk                (sys_clk            ), //input clk
    .pll_lock           (ddr_lock           ), //input pll_lock
    .rst_n              (sys_rst_n          ), //input rst_n
    .app_burst_number   (app_burst_number   ), //input [5:0] app_burst_number
    .cmd_ready          (cmd_ready          ), //output cmd_ready
    .cmd                (cmd                ), //input [2:0] cmd
    .cmd_en             (cmd_en             ), //input cmd_en
    .addr               (addr               ), //input [27:0] addr
    .wr_data_rdy        (wr_data_rdy        ), //output wr_data_rdy
    .wr_data            (wr_data            ), //input [127:0] wr_data
    .wr_data_en         (wr_data_en         ), //input wr_data_en
    .wr_data_end        (wr_data_end        ), //input wr_data_end
    .wr_data_mask       (wr_data_mask       ), //input [15:0] wr_data_mask
    .rd_data            (rd_data            ), //output [127:0] rd_data
    .rd_data_valid      (rd_data_valid      ), //output rd_data_valid
    .rd_data_end        (rd_data_end        ), //output rd_data_end
    .sr_req             (                   ), //input sr_req
    .ref_req            (                   ), //input ref_req
    .sr_ack             (                   ), //output sr_ack
    .ref_ack            (                   ), //output ref_ack
    .init_calib_complete(init_calib_complete), //output init_calib_complete
    .clk_out            (dma_clk            ), //output clk_out
    .ddr_rst            (                   ), //output ddr_rst
    .burst              (1'b1               ), //input burst

    //DDR3 PHY
    .O_ddr_addr         (O_ddr_addr         ), //output [13:0] O_ddr_addr
    .O_ddr_ba           (O_ddr_ba           ), //output [2:0] O_ddr_ba
    .O_ddr_cs_n         (O_ddr_cs_n         ), //output O_ddr_cs_n
    .O_ddr_ras_n        (O_ddr_ras_n        ), //output O_ddr_ras_n
    .O_ddr_cas_n        (O_ddr_cas_n        ), //output O_ddr_cas_n
    .O_ddr_we_n         (O_ddr_we_n         ), //output O_ddr_we_n
    .O_ddr_clk          (O_ddr_clk          ), //output O_ddr_clk
    .O_ddr_clk_n        (O_ddr_clk_n        ), //output O_ddr_clk_n
    .O_ddr_cke          (O_ddr_cke          ), //output O_ddr_cke
    .O_ddr_odt          (O_ddr_odt          ), //output O_ddr_odt
    .O_ddr_reset_n      (O_ddr_reset_n      ), //output O_ddr_reset_n
    .O_ddr_dqm          (O_ddr_dqm          ), //output [1:0] O_ddr_dqm
    .IO_ddr_dq          (IO_ddr_dq          ), //inout [15:0] IO_ddr_dq
    .IO_ddr_dqs         (IO_ddr_dqs         ), //inout [1:0] IO_ddr_dqs
    .IO_ddr_dqs_n       (IO_ddr_dqs_n       )  //inout [1:0] IO_ddr_dqs_n
);

//---------------------------------------------------
//输出同步时序模块
wire out_de;
syn_gen syn_gen_inst
(                                   
    .I_pxl_clk   (pix_clk       ),//40MHz      //65MHz      //74.25MHz    //148.5
    .I_rst_n     (sys_rst_n       ),//800x600    //1024x768   //1280x720    //1920x1080    
    .I_h_total   (16'd1650        ),// 16'd1056  // 16'd1344  // 16'd1650   // 16'd2200  
    .I_h_sync    (16'd40          ),// 16'd128   // 16'd136   // 16'd40     // 16'd44   
    .I_h_bporch  (16'd220         ),// 16'd88    // 16'd160   // 16'd220    // 16'd148   
    .I_h_res     (16'd1280        ),// 16'd800   // 16'd1024  // 16'd1280   // 16'd1920  
    .I_v_total   (16'd750         ),// 16'd628   // 16'd806   // 16'd750    // 16'd1125   
    .I_v_sync    (16'd5           ),// 16'd4     // 16'd6     // 16'd5      // 16'd5      
    .I_v_bporch  (16'd20          ),// 16'd23    // 16'd29    // 16'd20     // 16'd36      
    .I_v_res     (16'd720         ),// 16'd600   // 16'd768   // 16'd720    // 16'd1080   
    .I_rd_hres   (16'd1280        ),
    .I_rd_vres   (16'd720         ),
    .I_hs_pol    (1'b1            ),//HS polarity , 0:负极性，1：正极性
    .I_vs_pol    (1'b1            ),//VS polarity , 0:负极性，1：正极性
    .O_rden      (syn_off0_re     ),
    .O_de        (out_de          ),   
    .O_hs        (syn_off0_hs     ),
    .O_vs        (syn_off0_vs     )
);

assign rgb_data    = {off0_syn_data[15:11],3'd0,off0_syn_data[10:5],2'd0,off0_syn_data[4:0],3'd0};//{r,g,b}

hdmi_rPLL u_tmds_pll(
    .clkout(serial_clk), //output clkout
    .lock(pll_lock), //output lock
    .clkin(sys_clk) //input clkin
);

assign hdmi4_rst_n = sys_rst_n & pll_lock;

Gowin_CLKDIV u_Gowin_CLKDIV(
    .clkout(pix_clk), //output clkout
    .hclkin(serial_clk), //input hclkin
    .resetn(hdmi4_rst_n), //input resetn
    .calib(1) //input calib
);

DVI_TX_Top DVI_TX(
    .I_rst_n            (hdmi4_rst_n    ), //input I_rst_n
    .I_serial_clk       (serial_clk     ), //input I_serial_clk
    .I_rgb_clk          (pix_clk        ), //input I_rgb_clk
    .I_rgb_vs           (syn_off0_vs    ), //input I_rgb_vs
    .I_rgb_hs           (syn_off0_hs    ), //input I_rgb_hs
    .I_rgb_de           (out_de         ), //input I_rgb_de
    .I_rgb_r            (rgb_data[23:16]), //input [7:0] I_rgb_r
    .I_rgb_g            (rgb_data[15: 8]), //input [7:0] I_rgb_g
    .I_rgb_b            (rgb_data[ 7: 0]), //input [7:0] I_rgb_b
    .O_tmds_clk_p       (O_tmds_clk_p   ), //output O_tmds_clk_p
    .O_tmds_clk_n       (O_tmds_clk_n   ), //output O_tmds_clk_n
    .O_tmds_data_p      (O_tmds_data_p  ), //output [2:0] O_tmds_data_p
    .O_tmds_data_n      (O_tmds_data_n  ) //output [2:0] O_tmds_data_n
);

endmodule 