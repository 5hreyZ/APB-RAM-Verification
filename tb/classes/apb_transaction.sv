// =============================================================================
// File: apb_transaction.sv
// Description: Constrained-Random Transaction / Sequence Item for APB4
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_TRANSACTION_SV
`define APB_TRANSACTION_SV

import apb_pkg::*;

class apb_transaction;

    // -------------------------------------------------------------------------
    // Randomized Stimulus Fields
    // -------------------------------------------------------------------------
    rand bit [APB_ADDR_WIDTH-1:0] addr;
    rand bit [APB_DATA_WIDTH-1:0] data;
    rand apb_trans_type_e         trans_type;
    rand bit [APB_STRB_WIDTH-1:0] strb;
    rand bit [2:0]                prot;
    rand int unsigned             idle_cycles;
    rand bit                      is_err_expected;

    // -------------------------------------------------------------------------
    // Response & Observed Fields
    // -------------------------------------------------------------------------
    bit [APB_DATA_WIDTH-1:0]      rdata;
    apb_resp_e                    resp;
    int unsigned                  trans_id;

    // -------------------------------------------------------------------------
    // Constraints for Protocol Rules & Verification Scenarios
    // -------------------------------------------------------------------------
    // Default valid address in memory space
    constraint c_default_addr {
        addr inside {[APB_BASE_ADDR : APB_MAX_ADDR]};
    }

    // Default 4-byte word alignment
    constraint c_default_align {
        addr[1:0] == 2'b00;
    }

    // Default valid byte strobes (at least one byte enabled)
    constraint c_default_strb {
        strb inside {[4'b0001 : 4'b1111]};
    }

    // Random idle cycles between consecutive transfers (0 = back-to-back burst)
    constraint c_default_idle {
        idle_cycles dist { 0 := 40, [1:2] := 40, [3:5] := 20 };
    }

    // Balanced Read vs Write distribution
    constraint c_rw_dist {
        trans_type dist { APB_WRITE := 50, APB_READ := 50 };
    }

    constraint c_prot_default {
        prot == 3'b000;
    }

    constraint c_err_default {
        is_err_expected == 1'b0;
    }

    // -------------------------------------------------------------------------
    // Methods: Constructor, Copy, Clone, Compare, Print
    // -------------------------------------------------------------------------
    function new(string name = "apb_transaction");
        static int global_id = 0;
        this.trans_id = ++global_id;
        this.resp     = APB_OKAY;
        this.rdata    = '0;
    endfunction

    virtual function void copy(apb_transaction rhs);
        if (rhs == null) return;
        this.addr            = rhs.addr;
        this.data            = rhs.data;
        this.trans_type      = rhs.trans_type;
        this.strb            = rhs.strb;
        this.prot            = rhs.prot;
        this.idle_cycles     = rhs.idle_cycles;
        this.is_err_expected = rhs.is_err_expected;
        this.rdata           = rhs.rdata;
        this.resp            = rhs.resp;
        this.trans_id        = rhs.trans_id;
    endfunction

    virtual function apb_transaction clone();
        apb_transaction cloned = new();
        cloned.copy(this);
        return cloned;
    endfunction

    virtual function bit compare(apb_transaction rhs);
        if (rhs == null) return 1'b0;
        if (this.addr !== rhs.addr) return 1'b0;
        if (this.trans_type !== rhs.trans_type) return 1'b0;
        if (this.resp !== rhs.resp) return 1'b0;
        if (this.trans_type == APB_READ && this.rdata !== rhs.rdata) return 1'b0;
        return 1'b1;
    endfunction

    virtual function string convert2string();
        string s;
        string t_str = (trans_type == APB_WRITE) ? "WRITE" : "READ ";
        string r_str = (resp == APB_OKAY) ? "OKAY " : "ERROR";
        s = $sformatf("[ID:%0d | %s | Addr:0x%08h | WData:0x%08h | RData:0x%08h | Strb:4'b%4b | Resp:%s | Idle:%0d | ErrExp:%0b]",
                      trans_id, t_str, addr, data, rdata, strb, r_str, idle_cycles, is_err_expected);
        return s;
    endfunction

    virtual function void print();
        $display("%s", convert2string());
    endfunction

endclass : apb_transaction

`endif // APB_TRANSACTION_SV
