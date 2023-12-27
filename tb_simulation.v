`timescale 1ns/1ps 
/**************************************************************************/
/******************** Testbench for simulation ****************************/
/**************************************************************************/

/*************************** **********************************************/
/*************************** Definition file ******************************/
/*************************** **********************************************/
`define INPUTFILENAME		 "seaG.hex" // Input file name
`define OUTPUTFILENAME		 "seaSB.bmp"		// Output file name
`define OUTPUTHEXFILE		 "seaSB.hex"
// Choose the operation of code by delete // in the beginning of the selected line

`define SOBEL_OPERATION
//`define GAUSSIAN_BLUR_OPERATION
`define GRAYSCALE_OPERATION

module tb_simulation;

//-------------------------------------------------
// Internal Signals
//-------------------------------------------------

reg HCLK, HRESETn;
reg mode;
wire          hsync;
wire [ 7 : 0] data_R;
wire [ 7 : 0] data_G;
wire [ 7 : 0] data_B;
wire File_Closed;

//-------------------------------------------------
// Components
//-------------------------------------------------

image_read 
#(.INFILE(`INPUTFILENAME))
	u_image_read
( 
    .HCLK	            (HCLK    ),
    .HRESETn	        (HRESETn ),
    .HSYNC	            (hsync   ),
    .mode               (mode   ),
    .DATA_R	            (data_R ),
    .DATA_G	            (data_G ),
    .DATA_B	            (data_B )
); 

image_write 
#(.INFILE1(`OUTPUTFILENAME), .INFILE2(`OUTPUTHEXFILE))
	u_image_write
(
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .hsync(hsync),
    .DATA_WRITE_R(data_R),
    .DATA_WRITE_G(data_G),
    .DATA_WRITE_B(data_B),
    .File_Closed(File_Closed)
);	

//-------------------------------------------------
// Test Vectors
//-------------------------------------------------
initial begin 
    HCLK = 0;
    mode = 1;
    forever #10 HCLK = ~HCLK;
end

initial begin
    HRESETn     = 0;
    #25 HRESETn = 1;
end

always @ (*) 
	if(File_Closed)
		#10 $finish;

endmodule