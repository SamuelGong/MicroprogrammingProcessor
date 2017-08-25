`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:17:50 06/01/2017 
// Design Name: 
// Module Name:    micro_controller 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module micro_controller(	input	[31:0] inst,
							input clk, rst,
							output PCWriteCond,	PCWrite,	IorD, 	MemRead,
										MemWrite, 		IRWrite,	ext,
										RegWrite,
							output beq_o,		bne_o,
							output [1:0] MemToReg,	RegDst,	ALUsrcA, PCsrc,
							output [2:0] ALUsrcB,
							output reg [3:0] ALUop,
							output [4:0] State_o
    );
	 
	 // first decoder
	 M_decoder decoder( 	.inst(inst),
								.Rtype(Rtype), .Itype(Itype), .shift(shift), .MemAccess(MemAccess),
								.branch(branch), .addr(addr), .subr(subr), .andr(andr), .orr(orr),
								.sltr(sltr), .norr(norr), .xorr(xorr), .srl(srl), .sll(sll), .j(j),
								.jr(jr), .jal(jal), .jalr(jalr), .addi(addi), .andi(andi), 
								.beq(beq), .bne(bne),
								.ori(ori), .slti(slti), .xori(xori), .lui(lui), .lw(lw), .sw(sw));
	
	assign bne_o = bne;
	assign beq_o = beq;
	
	wire [1:0] op;
	// op == 00 for specific
	// op == 01 for add
	// op == 10 for subtract
	// op == 11 for shift left and default
	always @ * begin
		case(op)
			2'd0:	begin
						if(addr || addi) 	ALUop <= 4'd2;
						else if(subr)		ALUop <= 4'd6;
						else if(andr || andi)	ALUop <= 4'd0;
						else if(orr  || ori)		ALUop <= 4'd1;
						else if(xorr || xori)	ALUop <= 4'd3;
						else if(norr)				ALUop <= 4'd4;
						else if(sltr || slti)	ALUop <= 4'd7;
						else if(srl)				ALUop <= 4'd5;
						else if(sll)				ALUop <= 4'd8;
					end
			2'd1: ALUop <= 4'd2;
			2'd2: ALUop <= 4'd6;
			2'd3: ALUop <= 4'd8;
			default: ;
		endcase
	end
	
	wire [2:0] AddrCtrl;
	//	AddrCtrl == 000 for back to state 0
	// AddrCtrl == 001 for general decode
	// AddrCtrl == 010 for lw/sw decode
	// AddrCtrl == 011 for state++
	// AddrCtrl == 100 for R-type ALU completion
	// AddrCtrl == 101 for I-type ALU completion
									
	//	seconde decoder
	reg [4:0] state;
	always @ (posedge clk or posedge rst) begin
		if(rst) state <= 5'd0;
		else case(AddrCtrl)
			3'd0: state <= 5'd0;
			3'd1: begin
						if(lw | sw) 
										state <= 5'd2;
						else if(addr | subr | andr | orr | xorr | norr | sltr)
										state <= 5'd6;
						else if(addi | slti)
										state <= 5'd10;
						else if(andi | ori | xori)
										state <= 5'd11;
						else if(branch)
										state <= 5'd8;
						else if(j)
										state <= 5'd9;
						else if(jal)
										state <= 5'd16;
						else if(shift)
										state <= 5'd13;
						else if(lui)
										state <= 5'd14;
						else if(jr)
										state <= 5'd15;
						else if(jalr)
										state <= 5'd17;
					end
			3'd2:	begin
						if(lw)
							state <= 5'd3;
						else if(sw)
							state <= 5'd5;
					end
			3'd3: state <= state + 5'd1;
			3'd4: state <= 5'd7;
			3'd5: state <= 5'd12;
			default:;
		endcase
	end
	
	assign State_o = state;
														
	//											22.PCWriteCond		21.PCWrite		20.MemWrite				
	//19.IRWrite		18.RegWrite 	17.PCsrc[1]			16.PCsrc[0]		15.RegDst[1]
	//14.RegDst[0]		13.MemToReg[1] 12.MemToReg[0] 	11.ALUsrcA[1]	10.ALUsrcA[0]
	//9.ALUsrcB[2]		8.ALUsrcB[1]	7.ALUsrcB[0]		6.op[1]			5.op[0]
	//4.IorD				3.ext				2.AddrCtrl[2]		1.AddrCtrl[1]	0.AddrCtrl[0]
	
	reg [22:0] ctrl[0:17];
	always @(posedge rst) begin
		// for	instruction fetch 	## 	+1		(-1)
		ctrl[0] <= 23'b01010000000000010100011; 
		
		// for	waiting state			## 	1		(0)
		ctrl[1] <= 23'b00000000000000110101001; 
		
		// for	calculate memaddr		##		2		(1)
		ctrl[2] <= 23'b00000000000010100101010;
		
		// for	read memory				##		+1		(2)
		ctrl[3] <= 23'b00000000000000001110011;
		
		// for	write back				## 	0		(4)
		ctrl[4] <= 23'b00001000001000001100000;
		
		// for	write memory			##		0		(5)
		ctrl[5] <= 23'b00100000000000001110000;
		
		// for	Rtype-ALU execution	##		5		(6)
		ctrl[6] <= 23'b00000000000010000000100;
		
		// for 	Rtype-ALU completion	##		0		(7)
		ctrl[7] <= 23'b00001000100000001100000;
		
		// for	branch execution		##		+1		(8)
		ctrl[8] <= 23'b10000010000010001000000;
		
		/*
		// for branch completion		##		0		(?)
		ctrl[9] <= 23'b00000000000000001100000;*/
		
		// for jump execution			##		4		(9)
		ctrl[9]	<= 23'b01000100000000001100000;
		
		// for Itype-ALU_signedext execution	##		+1		(10)
		ctrl[10] <= 23'b00000000000010100001101;
		
		// for Itype-ALU_zeroext execution		##		6		(10)
		ctrl[11] <= 23'b00000000000010100000101;
		
		// for Itype-ALU completion				##		0		(11)
		ctrl[12] <= 23'b00001000000000001100000;
		
		// for shift execution						##		5		(12)
		ctrl[13] <= 23'b00000000000101000000100;
		
		// for lui execution							##		6		(13)
		ctrl[14] <= 23'b00000000000111011100101;
		
		// for jump register execution			##		4		(14)
		ctrl[15] <= 23'b01000110000000001100000;
		
		// for jal completion						##		0		(9)
		ctrl[16] <= 23'b01001101010000001100000;
		
		// for jalr completion						##		0		(14)
		ctrl[17] <= 23'b01001110110000001100000;
	end
	
	assign PCWriteCond = ctrl[state][22];
	assign PCWrite = ctrl[state][21];
	assign MemWrite = ctrl[state][20];
	assign IRWrite = ctrl[state][19];
	assign RegWrite = ctrl[state][18];
	assign PCsrc[1] = ctrl[state][17];
	assign PCsrc[0] = ctrl[state][16];
	assign RegDst[1] = ctrl[state][15];
	assign RegDst[0] = ctrl[state][14];
	assign MemToReg[1] = ctrl[state][13];
	assign MemToReg[0] = ctrl[state][12];
	assign ALUsrcA[1] = ctrl[state][11];
	assign ALUsrcA[0] = ctrl[state][10];
	assign ALUsrcB[2] = ctrl[state][9];
	assign ALUsrcB[1] = ctrl[state][8];
	assign ALUsrcB[0] = ctrl[state][7];
	assign op[1] = ctrl[state][6];
	assign op[0] = ctrl[state][5];
	assign IorD = ctrl[state][4];
	assign ext = ctrl[state][3];
	assign AddrCtrl[2] = ctrl[state][2];
	assign AddrCtrl[1] = ctrl[state][1];
	assign AddrCtrl[0] = ctrl[state][0];

endmodule
