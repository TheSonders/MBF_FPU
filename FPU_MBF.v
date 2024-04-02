`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
/*
MIT License

Copyright (c) 2024 Antonio Sánchez (@TheSonders)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

 Antonio Sánchez (@TheSonders)
 Mar/2024
 References:
 -AMSTRAD CPC464 WHOLE MEMORY GUIDE (Don Thomasson) Chapter 13
    (From the Spanish Edition by Rafael Sarmiento de Sotomayor)
-https://en.wikipedia.org/wiki/Microsoft_Binary_Format

MBF40bits (aka 9-digit BASIC) FPU (copro) for a Z80 CPU

Connect to the 8-bit bus,
generates the wait signal when it tries to be read before it has finished.

Only performs addition, subtraction, multiplication and division in floating point.

***STILL IN DEBUGGING***

*/
///////////////////////////////////////////////////////////////////////////


module FPU_MBF(
	input wire CLK,
	input wire RD_n,
	input wire WR_n,
	input wire CS_n,
	input wire [7:0]DATA_in,
	output wire [7:0]DATA_out,
	output wire BUSY_n);
	
	localparam fadd = 'h34;
	localparam fsub = 'h36;
	localparam fmul = 'h37;
	localparam fdiv = 'h13;
	
	localparam STM_Start 	=  0;
	localparam STM_Unpack 	=  1;
	localparam STM_DeNorm	=  2;
	localparam STM_Prepare	=  3;
	
	localparam STM_Sample 	=  4;
	localparam STM_Normal	=  5;
	localparam STM_Restore	=  6;
	localparam STM_Idle		=  7;
	
	`define BusRead					(pRD_n & ~RD_n & ~CS_n)
	`define BusWrite					(pWR_n & ~WR_n & ~CS_n)
	
	`define Dividend_Exponent		register[10]
	`define Dividend_Sign 			(register[9][7])
	`define Dividend_Mantissa 		{register[9][6:0],register[8],register[7],register[6]}
	`define Dividend					{register[9],register[8],register[7],register[6]}
	
	`define Divider_Exponent		register[5]
	`define Divider_Sign 			(register[4][7])
	`define Divider_Mantissa 		{register[4][6:0],register[3],register[2],register[1]}
	`define Divider					{register[4],register[3],register[2],register[1]}
	
	`define Opcode						register[0]
	
	`define INC(re)					re<=re+1
	`define DEC(re)					re<=re-1
	
	
	reg [7:0]register[0:10];
	
	assign BUSY_n=(~RD_n & ~CS_n)?~Busy:1;
	assign DATA_out=(~RD_n & ~CS_n)?register[0]:'hZZ;
	
	integer x=0;
	initial begin
		for (x=0;x<11;x=x+1) begin
			register[x]<=0;
		end
		#2500 $display("STM=%d",STM);
				$display("RESULT=%h",{register[5],register[4],register[3],register[2],register[1]});
	end
	
	reg pRD_n=0;
	reg pWR_n=0;
	reg Busy=0;
	reg Add_Sub=0;
	
	reg [3:0]STM=STM_Start;
	reg [4:0]Shf_Counter=0;
	reg Dividend_Sign=0;
	reg Divider_Sign=0;
	reg unsigned[63:0]Accumulator=0;
	reg unsigned[63:0]Multiplicand=0;
	reg [31:0]Result=0;
	reg Carry;
	reg ResultSign=0;
	reg [8:0]Exponent=0;
	
	always @(posedge CLK)begin
		pRD_n<=RD_n;
		pWR_n<=WR_n;
		
		if (`BusWrite)begin
			for (x=10;x>0;x=x-1) begin
				register[x]<=register[x-1];
			end
			register[0]<=DATA_in;
			STM<=STM_Start;
			Busy<=1;
		end
		
		else if (`BusRead && ~Busy)begin
			for (x=0;x<10;x=x+1) begin
				register[x]<=register[x+1];
			end
			register[10]<='h00;
		end
	
		else begin
			case (STM)
				STM_Start:begin
					STM<=STM_Unpack;
				end
				STM_Unpack:begin
					if (`Opcode==fadd || `Opcode ==fsub)STM<=STM_DeNorm;
					else STM<=STM_Prepare;
					`Dividend<={1'b1,`Dividend_Mantissa};
					`Divider<={1'b1,`Divider_Mantissa};
					Dividend_Sign=`Dividend_Sign;
					Divider_Sign=`Divider_Sign;
					Shf_Counter<=31;
					Accumulator<=0;
					Multiplicand<={1'b1,`Dividend_Mantissa};
					Result<=0;
					Carry<=0;
					if (`Opcode==fmul)Exponent<=`Dividend_Exponent+`Divider_Exponent;
					else if (`Opcode==fdiv)Exponent<=(`Dividend_Exponent-`Divider_Exponent)+9'h81;
				end
				STM_DeNorm:begin
					if (`Dividend_Exponent<`Divider_Exponent)begin
						`INC(`Dividend_Exponent);
						`Dividend<=`Dividend>>1;
					end
					else if (`Divider_Exponent<`Dividend_Exponent)begin
						`INC(`Divider_Exponent);
						`Divider<=`Divider>>1;
					end
					else begin
						STM<=STM_Prepare;
					end
				end
				STM_Prepare:begin
					case (`Opcode)
						fsub:begin
							if (Dividend_Sign==Divider_Sign)begin
								{Carry,Result}<=`Dividend-`Divider;
							end
							else begin
								{Carry,Result}<=`Dividend+`Divider;
							end
							STM<=STM_Sample;
						end
						fadd:begin
							if (Dividend_Sign==Divider_Sign)begin
								{Carry,Result}<=`Dividend+`Divider;
							end
							else begin
								{Carry,Result}<=`Dividend-`Divider;
							end
							STM<=STM_Sample;
						end
						fmul:begin
							if (Exponent<9'h80) begin
								RESULT_ZERO;
							end
							else begin
								`Divider_Exponent<=(Exponent-'h80);
								if (`Divider & 1 ==1)begin
									Accumulator<=Accumulator+Multiplicand;
								end
								`Divider<=`Divider>>1;
								`DEC(Shf_Counter);
								Multiplicand<=Multiplicand<<1;
								if (Shf_Counter==0)STM<=STM_Sample;
							end
						end
						fdiv:begin
							if (Exponent>9'hFF) begin
								RESULT_ZERO;
							end
							else begin
								`Divider_Exponent<=Exponent;
								if (`Divider>Multiplicand)begin
									Multiplicand<={Multiplicand[62:0],1'b0};
									Result<={Result[30:0],1'b0};
								end
								else begin
									Multiplicand<={Multiplicand-`Divider,1'b0};
									Result<={Result[30:0],1'b1};
								end
								`DEC(Shf_Counter);
								if ((Shf_Counter==0) || (Result[31]==1))STM<=STM_Sample;
							end
						end
					endcase
				end
				STM_Sample:begin
					case (`Opcode)
						fsub:begin
							if ({Carry,Result}==0)begin
								RESULT_ZERO;
							end
							else begin
								if (Dividend_Sign==Divider_Sign)begin
									ResultSign<=Carry;
									STM<=STM_Normal;
									if (Carry) Result<=~Result+1;
								end
								else begin
									ResultSign<=Dividend_Sign;
									if (Carry==1)begin
										`INC(`Divider_Exponent);
										STM<=STM_Restore;
									end
									else STM<=STM_Normal;
								end
							end
						end
						fadd: begin
							if ({Carry,Result}==0)begin
								RESULT_ZERO;
							end
							else begin
								if (Dividend_Sign==Divider_Sign)begin
									ResultSign<=Dividend_Sign;
									if (Carry==1)begin
										`INC(`Divider_Exponent);
										STM<=STM_Restore;
									end
									else STM<=STM_Normal;
								end
								else begin
									ResultSign<=Carry;
									STM<=STM_Normal;
									if (Carry) Result<=~Result+1;
								end
							end
						end
						fmul:begin
							if (Accumulator==0)begin
								RESULT_ZERO;
							end
							else begin
								if (Dividend_Sign==Divider_Sign)ResultSign<=0;
								else ResultSign<=1;
								if (Accumulator[63]==1)begin
									Result<=Accumulator[63:32];
									STM<=STM_Restore;
								end
								else begin
									Accumulator<=Accumulator<<1;
									`DEC(`Divider_Exponent);
								end
							end
						end
						fdiv:begin
							if (Dividend_Sign==Divider_Sign)ResultSign<=0;
							else ResultSign<=1;
							STM<=STM_Normal;
						end
						endcase
					end
				STM_Normal:begin				
					if (Result[31]==1)begin
						STM<=STM_Restore;
					end
					else begin
						`DEC(`Divider_Exponent);
						Result<=Result<<1;
					end
				end
				STM_Restore:begin
					`Divider<={ResultSign,Result[30:0]};
					STM<=STM_Idle;
				end
				STM_Idle:begin
					Busy<=0;
				end
			endcase
		end
	end
	
task RESULT_ZERO;
	begin
		`Divider_Exponent<=0;
		STM<=STM_Idle;
	end
endtask
endmodule
