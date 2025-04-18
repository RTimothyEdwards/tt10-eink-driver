// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

//-----------------------------------------------------------
// eink_display_emulator.v
//-----------------------------------------------------------
// This is a work in progress, starting with a simple SPI
// slave module.  It needs to be designed specifically to
// emulate the SSD1680 e-ink display driver.  The datasheet
// for the display driver can be found at:
//
// https://cdn-learn.adafruit.com/assets/assets/\
// 000/097/631/original/SSD1680_Datasheet.pdf
//
// The display driver has no signal outputs.  This module
// is only meant to be used as a testbench, and should
// display what commands have been received and flag any
// incorrect input.
//-----------------------------------------------------------
// Written by Tim Edwards
// Open Circuit Design,  March 27, 2025
//------------------------------------------------
// This file is distributed free and open source
//------------------------------------------------

// RESB ---  Reset (sense negative) (RES#)
// SCL  ---  Clock input (SCK)
// SDA  ---  Data  input (SDI)
// BUSY ---  Status output
// D_CB ---  Data/Command input (D/C#)
// CSB  ---  Chip  select (sense negative) (CS#)

// All serial bytes are read and written msb first.

`define COMMAND  3'b000
`define ADDRESS  3'b001
`define DATA     3'b010

module eink_display_emulator(RESB, SCL, SDA, CSB, BUSY, D_CB)

    input RESB;			// display reset (sense negative)
    input SCL;			// SPI clock
    input SDA;			// SPI data in (MOSI)
    input CSB;			// SPI select (sense negative)
    input D_CB;			// Data/Command select
    output BUSY;		// SPI status out

    reg  [7:0]  addr;
    reg		wrstb;
    reg		rdstb;
    reg  [2:0]  state;
    reg  [2:0]  count;
    reg		writemode;
    reg		readmode;
    reg  [2:0]	fixed;
    reg  [6:0]  predata;
    reg  [7:0]  ldata;

    // Readback data is captured on the falling edge of SCK so that
    // it is guaranteed valid at the next rising edge.

    always @(negedge SCK or posedge CSB) begin
        if (CSB == 1'b1) begin
            wrstb <= 1'b0;
            ldata  <= 8'b00000000;
        end else begin

            // After CSB low, 1st SCK starts command

            if (state == `DATA) begin
            	if (readmode == 1'b1) begin
                    if (count == 3'b000) begin
                	ldata <= idata;
                    end else begin
                	ldata <= {ldata[6:0], 1'b0};	// Shift out
                    end
                end

                // Apply write strobe on SCK negative edge on the next-to-last
                // data bit so that it updates data on the rising edge of SCK
                // on the last data bit.
 
                if (count == 3'b111) begin
                    if (writemode == 1'b1) begin
                        wrstb <= 1'b1;
                    end
                end else begin
                    wrstb <= 1'b0;
                end

            end else begin
                wrstb <= 1'b0;
            end		// ! state `DATA
        end		// ! CSB
    end			// always @ ~SCK

    always @(posedge SCK or posedge CSB) begin
        if (CSB == 1'b1) begin
            // Default state on reset
            addr <= 8'h00;
	    rdstb <= 1'b0;
            predata <= 7'b0000000;
            state  <= `COMMAND;
            count  <= 3'b000;
            readmode <= 1'b0;
            writemode <= 1'b0;
            fixed <= 3'b000;
        end else begin
            // After CSB low, 1st SCK starts command
            if (state == `COMMAND) begin
		rdstb <= 1'b0;
                count <= count + 1;
        	if (count == 3'b000) begin
	            writemode <= SDI;
	        end else if (count == 3'b001) begin
	            readmode <= SDI;
	        end else if (count < 3'b101) begin
	            fixed <= {fixed[1:0], SDI}; 
	        end else if (count == 3'b111) begin
	            state <= `ADDRESS;
	        end
            end else if (state == `ADDRESS) begin
	        count <= count + 1;
	        addr <= {addr[6:0], SDI};
	        if (count == 3'b111) begin
	            state <= `DATA;
		    if (readmode == 1'b1) begin
			rdstb <= 1'b1;
		    end
	        end else begin
		    rdstb <= 1'b0;
		end

            end else if (state == `DATA) begin
	        predata <= {predata[6:0], SDI};
	        count <= count + 1;
	        if (count == 3'b111) begin
	            if (fixed == 3'b001) begin
	                state <= `COMMAND;
	            end else if (fixed != 3'b000) begin
	                fixed <= fixed - 1;
	                addr <= addr + 1;	// Auto increment address (fixed)
	            end else begin	
	                addr <= addr + 1;	// Auto increment address (streaming)
	            end
		    if (readmode == 1'b1) begin
			rdstb <= 1'b1;
		    end
	        end else begin
		    rdstb <= 1'b0;
		end
            end		// ! state `DATA
        end		// ! CSB 
    end			// always @ SCK

endmodule // eink_display_emulator
`default_nettype wire
