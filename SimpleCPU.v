`timescale 1ns / 1ps

//-----------------------------------------|
// Author:                                 |
// A. Emre Unal                            |
// S001974                                 |
// emre.unal@ozu.edu.tr                    |
//-----------------------------------------|

module SimpleCPU(clk, rst, data_fromRAM, wrEn, addr_toRAM, data_toRAM);

parameter SIZE = 10;

parameter FI = 0; // Fetch Instruction
parameter DE = 1; // Decode Instruction
parameter FD1 = 2; // Fetch Data 1
parameter FD2 = 3; // Fetch Data 2
parameter EX = 4; // Execute
parameter WR_UP = 5; // Write Back & Update PC

parameter ADD = 0;
parameter NAND = 1;
parameter SRL = 2;
parameter LT = 3;
parameter CP = 4;
parameter CPI = 5;
parameter BZJ = 6;
parameter MUL = 7;

input clk, rst;
input wire [31:0] data_fromRAM;
output reg wrEn;
output reg [SIZE-1:0] addr_toRAM;
output reg [31:0] data_toRAM;

reg [2:0] state, stateNext;
reg [SIZE-1:0] pCounter, pCounterNext;

reg [31:0] memA, memANext;
reg [31:0] memB, memBNext;
reg [31:0] instruction, instructionNext;



reg gotCPIdata, gotCPIdataNext;

wire [2:0] opcodeDE;
wire immediateDE;
wire [SIZE-1:0] addrADE;
wire [SIZE-1:0] addrBDE;


assign opcodeDE = data_fromRAM[31:29];
assign immediateDE = data_fromRAM[28];
assign addrADE = data_fromRAM[27:14];
assign addrBDE = data_fromRAM[13:0];

wire [2:0] opcode;
wire immediate;
wire [SIZE-1:0] addrA;
wire [SIZE-1:0] addrB;

assign opcode = instruction[31:29];
assign immediate = instruction[28];
assign addrA = instruction[27:14];
assign addrB = instruction[13:0];

always@(posedge clk) begin
    state <= #1 stateNext;
    pCounter <= #1 pCounterNext;
    memA <= #1 memANext;
    memB <= #1 memBNext;
    instruction <= #1 instructionNext;

    gotCPIdata <= #1 gotCPIdataNext;
end

always@(*) begin
    stateNext = state;
    pCounterNext = pCounter;
    memANext = memA;
    memBNext = memB;
    instructionNext = instruction;

    gotCPIdataNext = gotCPIdata;
    addr_toRAM = 0;
    data_toRAM = 0;
    wrEn = 0;
    
    if(rst) begin
        stateNext = 0;
        pCounterNext = 0;       
        memANext = 0;
        memBNext = 0;
        instructionNext = 0;

        gotCPIdataNext = 0;
        wrEn = 0;
        addr_toRAM = 0;
        data_toRAM = 0;
    end
    else begin
        case(state)
            FI : begin
                wrEn = 0;
                addr_toRAM = pCounter;
                stateNext = DE;
            end
            DE : begin
                instructionNext = data_fromRAM;
                addr_toRAM = addrADE;
                if(immediateDE) begin
                    memBNext = addrBDE;
                end
                stateNext = FD1;
                case(opcodeDE)
                    CP : begin
                        if(immediateDE) begin
                            stateNext = EX;
                        end
                        else begin
                            addr_toRAM = addrBDE;
                            stateNext = FD2;
                        end
                    end
                    CPI : begin
                        if(!immediateDE) begin
                            addr_toRAM = addrBDE;
                            stateNext = FD2;
                        end
                    end
                endcase
            end
            FD1 : begin
                memANext = data_fromRAM;
                if(immediate && ~(opcode == CPI)) begin
                    stateNext = EX;
                end
                else begin
                    addr_toRAM = addrB;
                    stateNext = FD2;
                end
                case(opcode)
                    CPI : begin
                        instructionNext = {instruction[31:28], 4'b0000, data_fromRAM[SIZE-1:0], instruction[13:0]};
                    end
                    BZJ : begin
                        if(immediateDE) begin
                            stateNext = EX;
                        end
                    end
                endcase
            end
            FD2 : begin
                memBNext = data_fromRAM;
                stateNext = EX;
                case(opcode)
                    CPI : begin

                        if(~immediate && ~gotCPIdata) begin
                            instructionNext = {instruction[31:14], 4'b0000, data_fromRAM[SIZE-1:0]};
                            addr_toRAM = data_fromRAM[SIZE-1:0];
                            stateNext = FD2;

                            gotCPIdataNext = 1;

                        end
                    end
                endcase
            end
            EX : begin
                stateNext = WR_UP;
                case(opcode)
                    ADD : begin
                        memANext = memA + memB;
                    end
                    NAND : begin
                        memANext = ~(memA & memB);
                    end
                    SRL : begin
                        if(memB < 32) begin
                            memANext = memA >> memB;
                        end
                        else begin
                            memANext = memA << (memB - 32);
                        end
                    end
                    LT : begin
                        if(memA < memB) begin
                            memANext = 1;
                        end
                        else begin
                            memANext = 0;
                        end
                    end
                    CP : begin
                        memANext = memB;
                    end
                    CPI : begin

                        gotCPIdataNext = 0;
                        memANext = memB;
                    end
                    BZJ : begin
                        if(immediate) begin
                            pCounterNext = memA + addrB;
                        end
                        else begin
                            if(memB == 0) begin
                                pCounterNext = memA;
                            end
                            else begin
                                pCounterNext = pCounter + 1;
                            end
                        end
                        stateNext = FI;
                    end
                    MUL : begin
                        memANext = memA * memB;
                    end
                endcase
            end
            WR_UP : begin
                pCounterNext = pCounter + 1;
                wrEn = 1;
                addr_toRAM = addrA;
                data_toRAM = memA;
                stateNext = FI;
            end
        endcase
    end
end

endmodule
