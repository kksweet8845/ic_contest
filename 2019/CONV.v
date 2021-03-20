
`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output		busy,
	input		ready,
	output		iaddr,
	input		idata,

	output	reg cwr,
	output	reg[11:0] caddr_wr,
	output	reg[19:0] cdata_wr,

	output	reg crd,
	output	reg[11:0] caddr_rd,
	input	[19:0] cdata_rd,
	output	reg[2:0] csel);





reg [19:0] buffer[0:8];

reg [3:0] nxt_st, cur_st;
reg [11:0] addr;
reg [11:0] cnt;
reg [6:0] X, Y;
reg [1:0] dir [0:8];
reg [39:0] conv_res;
reg [19:0] relu_res;
reg [19:0] max_res;

parameter Waiting_data_st 		= 5'd0,
		  Loading_data_st  		= 5'd1,
		  Loading_p0_st			= 5'd2,
		  Loading_p1_st			= 5'd3,
		  Loading_p2_st 		= 5'd4,
		  Loading_p3_st			= 5'd5,
		  Loading_p4_st			= 5'd6,
		  Loading_p5_st			= 5'd7,
		  Loading_p6_st			= 5'd8,
		  Loading_p7_st			= 5'd9,
		  Loading_p8_st			= 5'd10,
		  Output_l0_st      	= 5'd11,
		  Loading_l0_data_st	= 5'd12,
		  Loading_l0_p0_st		= 5'd13,
		  Loading_l0_p1_st		= 5'd14,
		  Loading_l0_p2_st		= 5'd15,
		  Loading_l0_p3_st		= 5'd16,
		  Zero_panding_st		= 5'd17,
		  Max_pooling_ph0_st	= 5'd18,
		  Max_pooling_ph1_st	= 5'd19,
		  Max_pooling_ph2_st	= 5'd20,
		  Max_pooling_ph3_st	= 5'd21,
		  Output_l1_st			= 5'd22,
		  Finish_st				= 5'd23,
		  Conv_st				= 5'd24,
		  Relu_st       		= 5'd25;


always@(posedge clk or posedge reset) begin
	if(reset) begin
		cur_st <= Waiting_data_st;
		cnt <= 12'd0;
		pivot <= 12'b0;
		X <= 5'd0;
		Y <= 5'd0;
	end else begin
		case(cur_st)
			Waiting_data_st: begin
				X <= 5'd0;
				Y <= 5'd0;
				cnt <= 12'd0;
			end
			Loading_data_st: begin
				busy <= 1'b1;
				if(X-1 < 0 || Y - 1 < 0) begin
					iaddr <= 12'd0;
				end else iaddr <= (Y-1) << 6 + (X-1);
			end
			Loading_p0_st: begin
				if(X-1 < 0 || Y -1 < 0) begin
					buffer[0] <= 12'd0;
				end else buffer[0] <= idata;
				if(X-1 < 0) iaddr <= 12'd0;
				else iaddr <= (Y) << 6 + (X-1);
			end
			Loading_p1_st: begin
				if(X-1< 0) buffer[1] <= 20'd0;
				else buffer[1] <= idata;
				if(X-1 < 0 || Y + 1 > 6'd63) iaddr <= 12'd0;
				else iaddr <= (Y+1) << 6 + (X-1);
			end
			Loading_p2_st: begin
				if(X-1 < 0 || Y + 1 > 12'd63) buffer[2] <= 20'd0;
				else buffer[2] <= idata;
				if(Y-1<0) iaddr <= 12'd0;
				else iaddr <= (Y-1) << 6 + X;
			end
			Loading_p3_st: begin
				if(Y-1 < 0) buffer[3] <= 20'd0;
				else buffer[3] <= idata;
				iaddr <= Y << 6 + X;
			end
			Loading_p4_st: begin
				buffer[4] <= idata;
				if(Y+1 > 12'd63) iaddr <= 12'd0;
				else iaddr <= (Y+1) << 6 + X;
			end
			Loading_p5_st: begin
				if(Y+1 > 12'd63) buffer[5] <= 12'd0;
				else buffer[5] <= (Y+1) << 6 + X;
				if(Y-1 < 0 || X+1> 12'd63) iaddr <= 12'd0;
				else iaddr <= (Y-1) << 6 + (X+1);
			end
			Loading_p6_st: begin
				if(Y-1 < 0 || X+1 > 12'd63) buffer[6] <= 20'd0;
				else buffer[6] <= idata;
				if(X+1 > 12'd63) iaddr <= 12'd0;
				else iaddr <= (Y) << 6 + (X+1);
			end
			Loading_p7_st: begin
				if(X+1 > 12'd63) buffer[7] <= 20'd0;
				else buffer[7] <= idata;
				if(X+1 > 12'd63 || Y+1 > 12'd63) iaddr <= 12'd0;
				else iaddr <= (Y+1) << 6 + (X+1);
			end
			Loading_p8_st: begin
				if(X+1 > 5'd63 || Y+1 > 5'd63) buffer[8] <= 20'd0;
				else buffer[8] <= idata;
			end
			Conv_st: begin
				conv_res <= (buffer[0] * 20'h0a89e + buffer[1] * 20'h01004 + buffer[2] * 20'hfa6d7
							 + buffer[3] * 20'h092d5 + buffer[4] * 20'hf8f71 + buffer[5] * 20'hfc834
							 + buffer[6] * 20'h06d43 + buffer[7] * 20'hf6e54 + buffer[8] * 20'hfac19) / 9;
			end
			Relu_st: begin
				relu_res <= conv_res > 0 ? conv_res : 0;
			end
			Output_l0_st: begin
				cwr <= 1'b1;
				crd <= 1'b0;
				csel <= 3'b001;
				caddr_wr <= (Y) << 6 + (X);
				cdata_wr <= relu_res;
				X <= ( X == 5'd63) ? 5'd0 : X + 5'd1;
				Y <= ( X == 5'd63 ) ? (( Y == 5'd63 ) ? 0 : Y + 5'd1) : 5'd0;
				cnt <= ( cnt == 12'd4095 ) ? 0 : cnt + 12'd1;
			end
			Loading_l0_data_st: begin
				crd <= 1'b1;
				cwr <= 1'b0;
				cnt <= (cnt == 12'd4) ? 12'd0 : cnt + 12'd1;
				caddr_rd <= Y << 6 + X;
			end
			Loading_l0_p0_st: begin
				cnt <= (cnt == 12'd4) ? 12'd0 : cnt + 12'd1;
				caddr_rd <= Y << 6 + X+1;
				buffer[0] <= cdata_rd;
			end
			Loading_l0_p1_st: begin
				cnt <= (cnt == 12'd4) ? 12'd0 : cnt + 12'd1;
				caddr_rd <= (Y+1) << 6 + X;
				buffer[1] <= cdata_rd;
			end
			Loading_l0_p2_st: begin
				cnt <= (cnt == 12'd4) ? 12'd0 : cnt + 12'd1;
				caddr_rd <= (Y+1) << 6 + (X+1);
				buffer[2] <= cdata_rd;
			end
			Loading_l0_p3_st: begin
				cnt <= (cnt == 12'd4) ? 12'd0 : cnt + 12'd1;
				buffer[3] <= cdata_rd;
			end
			Max_pooling_ph0_st: begin
				max_res <= (buffer[0] > buffer[1]) ? buffer[0] : buffer[1];
			end
			Max_pooling_ph1_st: begin
				max_res <= (buffer[2] > max_res) ? buffer[2] : max_res;
			end
			Max_pooling_ph2_st: begin
				max_res <= (buffer[3] > max_res) ? buffer[3] : max_res;
			end
			Output_l1_st: begin
				cwr <= 3'b1;
				csel <= 3'b011;
				cdata_wr <= max_res;
				caddr_wr <= Y << 5 + X << 1;
				X <= (X == 5'd62) ? 0 : X + 5'd2;
				Y <= (X == 5'd62) ? (Y == 5'd62) ? 0 : Y + 5'd2 : Y;
				cnt <= ( cnt == 12'd1023 ) ? 0 : cnt + 12'd1;
			end
			Finish_st: begin
				busy <= 1'b0;
			end
		endcase
	end
end



always@(*) begin
	if(reset) begin
		nxt_st = Waiting_data_st;
	end else begin
		case(cur_st)
			Waiting_data_st: begin
				if(ready) nxt_st = Loading_data_st;
				else nxt_st = Waiting_data_st;
			end
			Loading_data_st: begin
				nxt_st = Loading_l0_p0_st;
			end
			Loading_l0_p0_st: begin
				nxt_st = Loading_l0_p1_st;
			end
			Loading_l0_p1_st: begin
				nxt_st = Loading_l0_p2_st;
			end
			Loading_l0_p2_st: begin
				nxt_st = Loading_l0_p3_st;
			end
			Loading_l0_p3_st: begin
				nxt_st = Loading_l0_p4_st;
			end
			Loading_l0_p4_st: begin
				nxt_st = Loading_l0_p5_st;
			end
			Loading_l0_p5_st: begin
				nxt_st = Loading_l0_p6_st;
			end
			Loading_l0_p6_st: begin
				nxt_st = Loading_l0_p7_st:
			end
			Loading_l0_p7_st: begin
				nxt_st = Loading_l0_p8_st;
			end
			Loading_l0_p8_st: begin
				nxt_st = Conv_st;
			end
			Conv_st: begin
				nxt_st = Relu_st;
			end
			Output_l0_st: begin
				if(cnt == 12'd4095) begin
					nxt_st = Loading_l0_data_st;
				end else if(cnt >= 12'd1) begin
					nxt_st = Loading_p3_st;
				end else begin
					nxt_st = Loading_p0_st;
				end
			end
			Loading_l0_data_st: begin
				nxt_st = Loading_l0_p1_st;
			end
			Loading_l0_p1_st: begin
				nxt_st = Loading_l0_p2_st;
			end
			Loading_l0_p2_st: begin
				nxt_st = Loading_l0_p3_st;
			end
			Loading_l0_p3_st: begin
				nxt_st = Max_pooling_ph0_st;
			end
			Max_pooling_ph0_st: begin
				nxt_st = Max_pooling_ph1_st;
			end
			Max_pooling_ph1_st: begin
				nxt_st = Max_pooling_ph2_st;
			end
			Max_pooling_ph2_st: begin
				nxt_st = Output_l1_st;
			end
			Output_l1_st: begin
				if(cnt == 12'd1023) begin
					nxt_st = Finish_st;
				end else nxt_st = Loading_l0_data_st;
			end
			Finish_st: begin
				nxt_st = Finish_st;
			end
		endcase
	end
end





endmodule




