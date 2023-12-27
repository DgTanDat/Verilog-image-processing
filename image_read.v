/******************************************************************************/
/******************  Module for reading and processing image     **************/
/******************************************************************************/

`define SOBEL_OPERATION
//`define GAUSSIAN_BLUR_OPERATION
`define GRAYSCALE_OPERATION
module image_read
#(
  parameter WIDTH 	= 300, 						// Image width
			HEIGHT 	= 400, 						// Image height
			INFILE  = "input.hex", 			// image file
			VALUE= 100,							// value for Brightness operation
			THRESHOLD= 90,						// Threshold value for Threshold operation
			SIGN=1								// Sign value using for brightness operation
													// SIGN = 0: Brightness subtraction
													// SIGN = 1: Brightness addition
)
(
	input HCLK,									// clock					
	input HRESETn,								// Reset (active low)
	input mode,
	output reg HSYNC,							// Horizontal synchronous pulse
	
	// An HSYNC indicates that one line of the image is transmitted.
	// Used to be a horizontal synchronous signals for writing bmp file.
    output reg [7:0]  DATA_R,					// 8 bit Red data (even)
    output reg [7:0]  DATA_G,					// 8 bit Green data (even)
    output reg [7:0]  DATA_B,					// 8 bit Blue data (even)
	// Process and transmit 2 pixels in parallel to make the process faster, you can modify to transmit 1 pixels or more if needed
	output			  ctrl_done					// Done flag
);			
//-------------------------------------------------
// Internal Signals
//-------------------------------------------------

localparam sizeOfLengthReal = WIDTH*HEIGHT*3; 	// image data : 1179648 bytes: 512 * 768 *3 
// local parameters for FSM
localparam		ST_IDLE 	= 2'b00,			// idle state
				ST_DATA		= 2'b11;			// state for data processing 
reg [1:0] cstate, 								// current state
		  nstate;								// next state			
reg start;										// start signal: trigger Finite state machine beginning to operate
reg HRESETn_d;									// delayed reset signal: use to create start signal
reg 		ctrl_data_run;						// control signal for data processing
reg [7:0]   total_memory [0 : sizeOfLengthReal-1];	// memory to store  8-bit data image
// temporary memory to save image data : size will be WIDTH*HEIGHT*3		
reg [7:0] org_R  [0 : WIDTH*HEIGHT - 1]; 			// temporary storage for R component
reg [7:0] org_G  [0 : WIDTH*HEIGHT - 1];			// temporary storage for G component
reg [7:0] org_B  [0 : WIDTH*HEIGHT - 1];			// temporary storage for B component

reg [7:0] img_pad [0:(WIDTH+2)*(HEIGHT+2)-1];
// counting variables
integer i, j;
// temporary signals for calculation: details in the paper.

integer temp1,temp2,temp3,a,b,value;							// temporary variables in invert and threshold operation
reg [ 9:0] row; 								// row index of the image
reg [10:0] col; 								// column index of the image
reg [18:0] data_count; 							// data counting for entire pixels of the image
//-------------------------------------------------//
// -------- Reading data from input file ----------//
//-------------------------------------------------//
initial begin
    $readmemh(INFILE,total_memory,0,sizeOfLengthReal-1); // read file from INFILE
	$display("load file successfully");
end
// use 3 intermediate signals RGB to save image data
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_R[WIDTH*i+j] = total_memory[WIDTH*3*i+3*j+0]; // save Red component
                org_G[WIDTH*i+j] = total_memory[WIDTH*3*i+3*j+1];// save Green component
                org_B[WIDTH*i+j] = total_memory[WIDTH*3*i+3*j+2];// save Blue component
            end
        end
	if(mode) begin
		for(i=0; i<HEIGHT+2; i=i+1) begin
			for(j=0; j<WIDTH+2; j=j+1) begin
				if( 0<i && i<HEIGHT+1 && 0<j && j<WIDTH+1)
					img_pad[(WIDTH+2)*i + j] = org_R[WIDTH*(i-1) + (j-1)];
				else
					img_pad[(WIDTH+2)*i + j] = 100;
			end
		end
	end
    end
end
//----------------------------------------------------//
// ---Begin to read image file once reset was high ---//
// ---by creating a starting pulse (start)------------//
//----------------------------------------------------//
always@(posedge HCLK, negedge HRESETn)
begin
    if(!HRESETn) begin
        start <= 0;
		HRESETn_d <= 0;
    end
    else begin											//        ______		 				
        HRESETn_d <= HRESETn;							//       |		|
		if(HRESETn == 1'b1 && HRESETn_d == 1'b0)		// __0___|	1	|___0____	: starting pulse
			start <= 1'b1;
		else
			start <= 1'b0;
    end
end

//------------------------------------------------------------------------------------------------//
// Finite state machine for reading RGB888 data from memory and creating hsync and vsync pulses --//
//------------------------------------------------------------------------------------------------//
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        cstate <= ST_IDLE;
    end
    else begin
        cstate <= nstate; // update next state 
    end
end
//-----------------------------------------//
//--------- State Transition --------------//
//-----------------------------------------//
// IDLE . DATA
always @(*) begin
	case(cstate)
		ST_IDLE: begin
			if(start)
				nstate = ST_DATA;
			else
				nstate = ST_IDLE;
		end				
		ST_DATA: begin
			if(ctrl_done)
				nstate = ST_IDLE;
			else 
				nstate = ST_DATA;	
		end
	endcase
end
// ------------------------------------------------------------------- //
// ----------------------- control signal ---------------------------- //
// ------------------------------------------------------------------- //
always @(*) begin
	ctrl_data_run  = 0;
	case(cstate)
		ST_DATA: ctrl_data_run  = 1; // trigger counting for data processing
	endcase
end

// counting data, column and row index for reading memory 
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
		data_count <= 0;
        row <= 0;
		col <= 0;
    end
	else begin
		if(ctrl_data_run) begin
			data_count <= data_count + 1;
			if(col == WIDTH - 1) begin
				row <= row + 1;
				col <= 0;
			end
			else
				col <= col + 1;
		end
	end
end

assign ctrl_done = (data_count >= WIDTH*HEIGHT-1)? 1'b1: 1'b0; // done flag
//-------------------------------------------------//
//-------------  Image processing   ---------------//
//-------------------------------------------------//
always @(*) begin
	HSYNC   = 1'b0;
	DATA_R = 0;
	DATA_G = 0;
	DATA_B = 0;                                                                              
	if(ctrl_data_run) begin
		
		HSYNC   = 1'b1;
		if(~mode) begin
		/**************************************/		
		/*   GRAYSCALE_OPERATION 	      */
		/**************************************/
		`ifdef GRAYSCALE_OPERATION	
			value = (org_B[WIDTH * row + col] + org_R[WIDTH * row + col] + org_G[WIDTH * row + col]) / 3;
			DATA_R <= value;
			DATA_G <= value;
			DATA_B <= value;	
		`endif
		end
		else begin
		/**************************************/		
		/*      GAUSSIAN_BLUR_OPERATION       */
		/**************************************/
		`ifdef GAUSSIAN_BLUR_OPERATION	
			temp1 = 94742*img_pad[(WIDTH+2) * row + col] + 118318*img_pad[(WIDTH+2) * row + col + 1] + 94742*img_pad[(WIDTH+2) * row + col + 2] 
			+ 118318*img_pad[(WIDTH+2) * (row+1) + col] + 147761*img_pad[(WIDTH+2) * (row+1) + col + 1] + 118318*img_pad[(WIDTH+2) * (row+1) + col + 2] 
			+ 94742*img_pad[(WIDTH+2) * (row+2) + col] + 118318*img_pad[(WIDTH+2) * (row+2) + col + 1] + 94742*img_pad[(WIDTH+2) * (row+2) + col + 2];
			value = temp1/1000000;
			temp2 = temp1%1000000;
			if (temp2 > 499999) begin
				value = value + 1;
			end
			else begin
				value = value;
			end
			DATA_R = value;
			DATA_G = value;
			DATA_B = value;	
		`endif
		/**************************************/		
		/*	SOBEL_OPERATION 	      */
		/**************************************/
		`ifdef SOBEL_OPERATION	
			temp1 = (-1)*img_pad[(WIDTH+2) * row + col]  + img_pad[(WIDTH+2) * row + col + 2] 
			+ (-2)*img_pad[(WIDTH+2) * (row+1) + col]  + (2)*img_pad[(WIDTH+2) * (row+1) + col + 2] 
			+ (-1)*img_pad[(WIDTH+2) * (row+2) + col]  + img_pad[(WIDTH+2) * (row+2) + col + 2];

			temp2 = (-1)*img_pad[(WIDTH+2) * row + col] + (-2)*img_pad[(WIDTH+2) * row + col + 1] + (-1)*img_pad[(WIDTH+2) * row + col + 2] 
			+ img_pad[(WIDTH+2) * (row+2) + col] + (2)*img_pad[(WIDTH+2) * (row+2) + col + 1] + img_pad[(WIDTH+2) * (row+2) + col + 2];

			if (temp1 < 0) temp1 = 0;
			else if (temp1 > 255) temp1 = 255;
			if (temp2 < 0) temp2 = 0;
			else if (temp2 > 255) temp2 = 255;
			a = (temp1 > temp2) ? temp1 : temp2;
			b = (temp1 > temp2) ? temp2 : temp1;
			temp3 = a*7/8 + b/2;
			if (a*7%8  > 4 || b % 2 == 1 ) temp3 = temp3 + 1;
			value = (temp3 > a) ? temp3 : a;
			DATA_R = value;
			DATA_G = value;
			DATA_B = value;	
		`endif
		end
	end
end
endmodule


