// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Receive and decode NEC or extended NEC IR Packets
// For info on NEC, see http://techdocs.altium.com/display/FPGA/NEC+Infrared+Transmission+Protocol
class IRreceiver {
    
    static NEC_START_TIME_HIGH_US 	= 9000.0;
	static NEC_START_TIME_LOW_US	= 4500.0;
	static NEC_PULSE_TIME_US		= 562.5;
	static NEC_LOW_TIME_US_1		= 1687.5;
	static NEC_LOW_TIME_US_0	    = 562.5;
	
	static NEC_DECODE_MARGIN_US     = 200.0;
	
	static RX_TIMEOUT_US        = 50000.0;
	
	_rxPin = null;
	_rxCallback = null;
	_idle_state = null;
	
	_rd = null;
	_us = null;
	
	constructor(rxPin, rxCb, idle_state = 1) {
	    _idle_state = idle_state;
	    _rxPin = rxPin;
	    _rxCallback = rxCb;
	    
	    _rd = _rxPin.read.bindenv(_rxPin);
	    _us = hardware.micros.bindenv(hardware);
	    
	    enable();
	}
	
	function enable() {
	    _rxPin.configure(DIGITAL_IN, _receiveDppm.bindenv(this));
	}
	
	function disable() {
	    _rxPin.configure(DIGITAL_IN);
	}
	
	function packetTableToBlob(packet_array) {
	    local bit_idx = 0;
	    local byte = 0;
	    // reserve space for up to a 256-bit IR packet; more allocated as needed
	    local packet = blob(32); 
	    local threshold_0 = NEC_LOW_TIME_US_0 + NEC_DECODE_MARGIN_US;
	    local threshold_1 = NEC_LOW_TIME_US_1 + NEC_DECODE_MARGIN_US;
	    
	    foreach (event in packet_array) {
	        if (event.level == 1) { continue; }
    	    if (event.duration < threshold_0) {
                byte = byte & ~(0x01 << bit_idx++);
            } else if (event.duration < threshold_1) {
                byte = byte | (0x01 << bit_idx++);
            } else {
                // too long to be a "0" or "1"; this is the start symbol, ignore
            }
            if (bit_idx == 8) {
                packet.writen(byte, 'b');
                byte = 0;
                bit_idx = 0;
            }
	    }
	    packet.seek(0);
	    return packet;
	}
	
	function decodeNec(packet_blob) {
	    packet_blob.seek(0);
	    local decoded = {};
	    
	    decoded.targetAddr      <- packet_blob.readn('b');
	    decoded.invTargetAddr   <- packet_blob.readn('b');
	    decoded.cmd             <- packet_blob.readn('b');
	    decoded.invCmd          <- packet_blob.readn('b');
	    decoded.raw <- (decoded.targetAddr << 24) + (decoded.invTargetAddr << 16) + (decoded.cmd << 8) + decoded.invCmd;
	    
	    if (decoded.targetAddr != (~decoded.invTargetAddr & 0xFF)) {
	        decoded.error <- "Addr / Inv Addr Mismatch";
	    } 
	    if (decoded.cmd != (~decoded.invCmd & 0xFF)) {
	        if (!("error" in decoded)) {
	            decoded.error <- "Cmd / Inv Cmd Mismatch";
	        }
	        decoded.error += ", Cmd / Inv Cmd Mismatch";
	    }
	    return decoded;
	}
	
	function decodeExtendedNec(packet_blob) {
	    packet_blob.seek(0);
	    local decoded = {};
	    
	    decoded.targetAddr      <- (packet_blob.readn('b') << 8) | packet_blob.readn('b');
	    decoded.cmd             <- packet_blob.readn('b');
	    decoded.invCmd          <- packet_blob.readn('b');
	    decoded.raw <- (decoded.targetAddr << 16) + (decoded.cmd << 8) + decoded.invCmd;

	    if (decoded.cmd != (~decoded.invCmd & 0xFF)) {
            decoded.error <- "Cmd / Inv Cmd Mismatch";
	    }
	    return decoded;
	}
	
	// Private methods ---------------------------------------------------------
	function _receiveDppm() {
        local packet = [];
	    local state = 0;
	    local last_state = _rd();
	    local duration = 0;
	    
	    local start = _us();
	    local last_change_time = start;
	    local now = start;
	    
	    while (1) {
	        // watch for pin state changes
	        state = _rd();
	        now = _us();
	        
	        // end receive loop if it's been more than the max packet time
	        if (state == last_state) {
	            if ((now - last_change_time) > RX_TIMEOUT_US) {
	                break;
	            }
	            continue;
	        }
	        
	        // state change detected
	        duration = now - last_change_time;
	        last_state = state;
			last_change_time = now;
			packet.push({"level": (state == _idle_state ? 1 : 0), "duration": duration});
	    }

	    _rxCallback(packet);
	}
}