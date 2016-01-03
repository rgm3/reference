// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Driver Class for Air Pressure Sensor LPS25H
// http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf

class LPS25H {
    // registers
    static LPS25H_REF_P_XL        = 0x08
    static LPS25H_REF_P_L         = 0X09
    static LPS25H_REF_P_H         = 0x0A
    static LPS25H_WHO_AM_I        = 0x0F
    static LPS25H_RES_CONF        = 0x10
    static LPS25H_CTRL_REG1       = 0x20
    static LPS25H_CTRL_REG2       = 0x21
    static LPS25H_CTRL_REG3       = 0x22
    static LPS25H_CTRL_REG4       = 0x23
    static LPS25H_INT_CFG         = 0x24
    static LPS25H_INT_SOURCE      = 0x25
    static LPS25H_STATUS_REG      = 0x27
    static LPS25H_PRESS_OUT_XL    = 0x28
    static LPS25H_PRESS_OUT_L     = 0x29
    static LPS25H_PRESS_OUT_H     = 0x2A
    static LPS25H_TEMP_OUT_L      = 0x2B
    static LPS25H_TEMP_OUT_H      = 0x2C
    static LPS25H_FIFO_CTRL       = 0x2E
    static LPS25H_FIFO_STATUS     = 0x2F
    static LPS25H_THS_P_L         = 0x30
    static LPS25H_THS_P_H         = 0x31
    static LPS25H_RPDS_L          = 0x39
    static LPS25H_RPDS_H          = 0x3A
    
    // constants
    static MEAS_TIME = 0.5; // seconds; time to complete pressure conversion
    
    // variables
    _i2c        = null;
    _addr       = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;
        
        init();
    }

    // -------------------------------------------------------------------------    
    function init() {
        return;
    }
    
    // -------------------------------------------------------------------------
    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return -1 * (value & mask);
    }

    // -------------------------------------------------------------------------    
    function _read(reg, numBytes) {
        local result = _i2c.read(_addr, reg.tochar(), numBytes);
        // if (result == null) {
        //     throw "I2C read error: " + _i2c.readerror();
        // }
        return result;
    }

    // -------------------------------------------------------------------------    
    function _write(reg, ...) {
        local s = reg.tochar();
        foreach (b in vargv) {
            s += b.tochar();
        }
        local result = _i2c.write(_addr, s);
        if (result) {
            server.error("I2C write error: " + result);
        }
        return result;
    }

    // -------------------------------------------------------------------------    
    function getDeviceID() {
        return _read(LPS25H_WHO_AM_I, 1);
    }

    // -------------------------------------------------------------------------        
    function enable(val) {
        local reg = _read(LPS25H_CTRL_REG1, 1);
        local res = _write(LPS25H_CTRL_REG1, reg[0] | (0x80 & val << 7));
    }

    // -------------------------------------------------------------------------        
    function getReferencePressure() {
        local data = _read(LPS25H_REF_P_XL, 3);
        return (data[2] << 16) | (data[1] << 8) | data[0];
    }
    
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function setPressNpts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x01
        } else if (npts <= 128) {
            // Average 128 readings
            npts = 0x02;
        } else {
            // Average 512 readings
            npts = 0x03;
        }
        local val = _read(LPS25H_RES_CONF, 1)[0];
        local res = _write(LPS25H_RES_CONF, (val & 0xFC) | npts);
    }    
    
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function setTempNpts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 16) {
            // Average 16 readings
            npts = 0x01
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x02;
        } else {
            // Average 64 readings
            npts = 0x03;
        }
        local val = _read(LPS25H_RES_CONF, 1);
        local res = _write(LPS25H_RES_CONF, (val & 0xF3) | (npts << 2));
    }    
    
    // -------------------------------------------------------------------------
    function setIntEnable(state) {
        local val = _read(LPS25H_CTRL_REG1, 1)[0];
        if (!state) {
            val = val & 0xF7; 
        } else {
            val = val | 0x08;
        }
        local res = _write(LPS25H_CTRL_REG1, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function setFifoEnable(state) {
        local val = _read(LPS25H_CTRL_REG2, 1)[0];
        if (state == 0) {
            val = val & 0xAF; 
        } else {
            val = val | 0x40;
        }
        local res = _write(LPS25H_CTRL_REG2, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function softReset(state) {
        local res = _write(LPS25H_CTRL_REG2, 0x04);
    }
    
    // -------------------------------------------------------------------------
    function setIntActivehigh(state) {
        local val = _read(LPS25H_CTRL_REG3, 1)[0];
        if (state == 0) {
            val = val | 0x80; 
        } else {
            val = val & 0x7F;
        }
        local res = _write(LPS25H_CTRL_REG3, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function setIntPushpull(state) {
        local val = _read(LPS25H_CTRL_REG3, 1)[0];
        if (state == 0) {
            val = val | 0x40; 
        } else {
            val = val & 0xBF;
        }
        local res = _write(LPS25H_CTRL_REG3, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function setIntConfig(latch, diff_press_low, diff_press_high) {
        local int_cfg = _read(LPS25H_INT_CFG, 1)[0];
        local ctrl3 = _read(LPS25H_CTRL_REG3, 1)[0];
        if (latch) {
            int_cfg = int_cfg | 0x04; 
        } 
        if (diff_press_low) {
            int_cfg = int_cfg | 0x02;
            ctrl3 = ctrl3 | 0x02;
        }
        if (diff_press_high) {
            int_cfg = int_cfg | 0x01;
            ctrl3 = ctrl3 | 0x01;
        }
        _write(LPS25H_INT_CFG, int_cfg & 0xFF);
        _write(LPS25H_CTRL_REG3, ctrl3 & 0xFF);
    }    
    
    // -------------------------------------------------------------------------
    function setPressThresh(press_thresh) {
        press_thresh = (press_thresh * 16.0).tointeger();
        _write(LPS25H_THS_P_H, (press_thresh & 0xff00) >> 8);
        _write(LPS25H_THS_P_L, press_thresh & 0xff);
    }  
    
    // -------------------------------------------------------------------------
    // Returns raw pressure register values
    function getRawPressure() {
        local low = _read(LPS25H_PRESS_OUT_XL, 1);
        local mid = _read(LPS25H_PRESS_OUT_L, 1);
        local high = _read(LPS25H_PRESS_OUT_H, 1);
        return ((high[0] << 16) | (mid[0] << 8) | low[0]);
    }
    
    // -------------------------------------------------------------------------    
    function getPressureHPa(cb = null) {
        // Wake up the sensor
        enable(1);
        // Start a one-shot measurement
        _write(LPS25H_CTRL_REG2, 0x01);
        if (cb) {
            imp.wakeup(MEAS_TIME, function() {
                local pressure = (getRawPressure() - getReferencePressure()) / 4096.0;
                enable(0);
                cb(pressure);
            }.bindenv(this));
        } else {
            imp.sleep(MEAS_TIME);
            local pressure = (getRawPressure() - getReferencePressure()) / 4096.0;
            enable(0);
            return pressure;
        }
    }
    
    // -------------------------------------------------------------------------
    // Returns Pressure in kPa
    function getPressureKPa() {    
        return gePressureHPa() / 10.0;
    }
    
    // -------------------------------------------------------------------------
    // Returns Pressure in inches of Hg
    function getPressureInHg() {    
        return getPressureHPa() * 0.0295333727;
    }    
    
    // -------------------------------------------------------------------------
    function getTemp() {
        enable(1);
        local temp_l = _read(LPS25H_TEMP_OUT_L, 1)[0];
        local temp_h = _read(LPS25H_TEMP_OUT_H, 1)[0];
        enable(0);
        
        local temp_raw = (temp_h << 8) | temp_l;
        if (temp_raw & 0x8000) {
            temp_raw = _twosComp(temp_raw, 0xFFFF);
        }
        return (42.5 + (temp_raw / 480.0));
    }
}