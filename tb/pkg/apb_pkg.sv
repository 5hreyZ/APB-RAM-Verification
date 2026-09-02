// =============================================================================
// File: apb_pkg.sv
// Description: APB Verification Package containing typedefs, enums, & utilities
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_PKG_SV
`define APB_PKG_SV

package apb_pkg;

    // -------------------------------------------------------------------------
    // Type Definitions and Enumerations
    // -------------------------------------------------------------------------
    typedef enum bit {
        APB_READ  = 1'b0,
        APB_WRITE = 1'b1
    } apb_trans_type_e;

    typedef enum bit {
        APB_OKAY  = 1'b0,
        APB_ERROR = 1'b1
    } apb_resp_e;

    typedef enum {
        LOG_INFO,
        LOG_WARN,
        LOG_ERROR,
        LOG_FATAL
    } apb_log_level_e;

    // -------------------------------------------------------------------------
    // Global Verification Constants
    // -------------------------------------------------------------------------
    parameter int APB_ADDR_WIDTH   = 32;
    parameter int APB_DATA_WIDTH   = 32;
    parameter int APB_STRB_WIDTH   = APB_DATA_WIDTH / 8;
    parameter int APB_MEM_DEPTH    = 1024;
    parameter bit [31:0] APB_BASE_ADDR = 32'h0000_0000;
    parameter bit [31:0] APB_MAX_ADDR  = APB_BASE_ADDR + (APB_MEM_DEPTH * APB_STRB_WIDTH) - 1;

    // -------------------------------------------------------------------------
    // Logging Utility Functions
    // -------------------------------------------------------------------------
    function automatic void apb_log(
        input apb_log_level_e level,
        input string tag,
        input string msg
    );
        string prefix;
        case (level)
            LOG_INFO:  prefix = "[INFO]";
            LOG_WARN:  prefix = "[WARN]";
            LOG_ERROR: prefix = "[ERROR]";
            LOG_FATAL: prefix = "[FATAL]";
            default:   prefix = "[LOG]";
        endcase
        $display("%0t | %-7s | %-12s | %s", $time, prefix, tag, msg);
        if (level == LOG_FATAL) begin
            $fatal(1, "%0t | Fatal error encountered in %s: %s", $time, tag, msg);
        end
    endfunction

endpackage : apb_pkg

`endif // APB_PKG_SV
