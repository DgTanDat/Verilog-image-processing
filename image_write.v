/******************************************************************************/
/******************     Module for writing .bmp image    		 *************/
/******************************************************************************/
module image_write
#(parameter WIDTH 	= 300,						// Image width
			HEIGHT 	= 400,						// Image height
			INFILE1  = "output.bmp",				// Output image
			INFILE2  = "out.hex",					//Output hex file
			BMP_HEADER_NUM = 54					// Header for bmp image
)
(
	input HCLK,									// Clock	
	input HRESETn,								// Reset active low
	input hsync,								// Hsync pulse						
    input [7:0]  DATA_WRITE_R,					// Red 8-bit data (odd)
    input [7:0]  DATA_WRITE_G,					// Green 8-bit data (odd)
    input [7:0]  DATA_WRITE_B,					// Blue 8-bit data (odd)
	output 	reg	 Write_Done,
    output reg File_Closed = 0
);	
reg [7:0] BMP_header [0 : BMP_HEADER_NUM - 1];	// BMP header
reg [7:0] out_BMP    [0 : WIDTH*HEIGHT*3 - 1];	// Temporary memory for image
integer data_count;								// Counting data
wire done;										// done flag
// counting variables
integer i;
integer k, row, col;
integer fd; 
//----------------------------------------------------------//
//-------Header data for bmp image--------------------------//
//----------------------------------------------------------//
// Windows BMP files begin with a 54-byte header: 
// Check the website to see the value of this header: http://www.fastgraph.com/help/bmp_header_format.html
initial begin
	BMP_header[ 0] = 66;BMP_header[28] =24;
	BMP_header[ 1] = 77;BMP_header[29] = 0;
	BMP_header[ 2] = 54;BMP_header[30] = 0;
	BMP_header[ 3] =  0;BMP_header[31] = 0;
	BMP_header[ 4] =  0;BMP_header[32] = 0;
	BMP_header[ 5] =  0;BMP_header[33] = 0;
	BMP_header[ 6] =  0;BMP_header[34] = 0;
	BMP_header[ 7] =  0;BMP_header[35] = 0;
	BMP_header[ 8] =  0;BMP_header[36] = 0;
	BMP_header[ 9] =  0;BMP_header[37] = 0;
	BMP_header[10] = 54;BMP_header[38] = 0;
	BMP_header[11] =  0;BMP_header[39] = 0;
	BMP_header[12] =  0;BMP_header[40] = 0;
	BMP_header[13] =  0;BMP_header[41] = 0;
	BMP_header[14] = 40;BMP_header[42] = 0;
	BMP_header[15] =  0;BMP_header[43] = 0;
	BMP_header[16] =  0;BMP_header[44] = 0;
	BMP_header[17] =  0;BMP_header[45] = 0;
	BMP_header[18] = 44;BMP_header[46] = 0;
	BMP_header[19] =  1;BMP_header[47] = 0;
	BMP_header[20] =  0;BMP_header[48] = 0;
	BMP_header[21] =  0;BMP_header[49] = 0;
	BMP_header[22] =144;BMP_header[50] = 0;
	BMP_header[23] =  1;BMP_header[51] = 0;	
	BMP_header[24] =  0;BMP_header[52] = 0;
	BMP_header[25] =  0;BMP_header[53] = 0;
	BMP_header[26] =  1;
	BMP_header[27] =  0;
end
// row and column counting for temporary memory of image 
always@(posedge HCLK, negedge HRESETn) begin
    if(!HRESETn) begin
        row <= 0;
        col <= 0;
    end else begin
        if(hsync) begin
            if(col == WIDTH-1) begin
                col <= 0;
                row <= row + 1; // count to obtain row index of the out_BMP temporary memory to save image data
            end else begin
                col <= col + 1; // count to obtain column index of the out_BMP temporary memory to save image data
            end
        end
    end
end
// Writing RGB888 even and odd data to the temp memory
always@(posedge HCLK, negedge HRESETn) begin
    if(!HRESETn) begin
        for(k=0;k<WIDTH*HEIGHT*3;k=k+1) begin
            out_BMP[k] <= 0;
        end
    end else begin
        if(hsync) begin
            out_BMP[WIDTH*3*row+3*col+2] <= DATA_WRITE_R;
            out_BMP[WIDTH*3*row+3*col+1] <= DATA_WRITE_G;
            out_BMP[WIDTH*3*row+3*col  ] <= DATA_WRITE_B;
        end
    end
end
// data counting
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        data_count <= 0;
    end
    else begin
        if(hsync)
			data_count <= data_count + 1; // pixels counting for create done flag
    end
end
assign done = (data_count == WIDTH*HEIGHT-1)? 1'b1: 1'b0; // done flag once all pixels were processed
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        Write_Done <= 0;
    end
    else begin
		Write_Done <= done;
    end
end
//---------------------------------------------------------//
//--------------Write .bmp file		----------------------//
//----------------------------------------------------------//
initial begin
    fd = $fopen(INFILE1, "wb+");
end
always@(Write_Done) begin // once the processing was done, bmp image will be created
    if(Write_Done == 1'b1) begin
	$writememh(INFILE2, out_BMP);
        for(i=0; i<BMP_HEADER_NUM; i=i+1) begin
            $fwrite(fd, "%c", BMP_header[i][7:0]); // write the header
        end
        
        for(i=0; i<WIDTH*HEIGHT*3; i=i+3) begin
		// write RBG
            $fwrite(fd, "%c", out_BMP[i  ][7:0]);
            $fwrite(fd, "%c", out_BMP[i+1][7:0]);
            $fwrite(fd, "%c", out_BMP[i+2][7:0]);
        end
        $fclose(fd);
        $display("Write file successfully!");
        File_Closed = 1;
    end
end
endmodule