# Verification Plan: AMBA APB RAM Controller

## 1. Overview & Verification Strategy

The objective of this verification environment is to achieve 100% protocol adherence, functional coverage, and data integrity verification for an AMBA APB4 Slave RAM Memory Controller. The verification strategy utilizes:
- **Constrained-Random Verification (CRV)** with SystemVerilog OOP to explore state spaces and unexpected corner cases.
- **Reference Model-based Scoreboarding** to verify byte-accurate write masking and read integrity.
- **SystemVerilog Assertions (SVA)** to monitor bus protocol rules continuously.
- **Functional Coverage (Covergroups & Crosses)** to track verification closure.

---

## 2. Feature Matrix & Test Mapping

| Feature ID | Feature Description | Verification Method | Targeted Testcase | Target Metric |
| :--- | :--- | :--- | :--- | :--- |
| **FT_SANITY** | Basic single write followed by single read | Directed Test | `test_base` | 100% data match |
| **FT_CRV** | Large-scale randomized Read/Write transfers | Constrained-Random | `test_random` | 1000 transfers, 0 errors |
| **FT_STRB** | Per-byte write enable masking (`PSTRB[3:0]`) | Directed / Random | `test_byte_strobe` | All 15 valid strobe combinations |
| **FT_ERR_OOB** | Out-of-bounds address access detection | Negative Injection | `test_error_handling` | `PSLVERR == 1` |
| **FT_ERR_ALIGN**| Unaligned address access detection | Negative Injection | `test_error_handling` | `PSLVERR == 1` |
| **FT_B2B** | Zero-idle back-to-back transfer bursts | Stress Testing | `test_b2b_stress` | Zero dropped handshakes |
| **FT_WAIT** | Multi-cycle wait states and signal stability | Protocol Stress | `test_wait_states` | Stable control signals during wait |

---

## 3. SystemVerilog Assertions (SVA) Checklist

| Assertion Name | Description | Protocol Standard Rule |
| :--- | :--- | :--- |
| `assert_setup_to_access` | `(PSEL && !PENABLE) \|=> (PSEL && PENABLE)` | APB SETUP phase must be followed by ACCESS phase. |
| `assert_access_completion`| `(PSEL && PENABLE && PREADY) \|=> (!PENABLE)` | ACCESS phase completes once PREADY is high. |
| `assert_stable_addr` | `(PSEL && PENABLE && !PREADY) \|=> $stable(PADDR)` | Address must remain constant during wait states. |
| `assert_stable_ctrl` | `(PSEL && PENABLE && !PREADY) \|=> $stable(PWRITE)` | Transfer direction must not change during wait states. |
| `assert_stable_wdata` | `(PSEL && PENABLE && !PREADY && PWRITE) \|=> $stable(PWDATA)` | Write data and byte strobes must remain constant. |
| `assert_pslverr_validity`| `PSLVERR \|-> (PSEL && PENABLE && PREADY)` | `PSLVERR` is only valid during active ready access. |
| `assert_reset_quiescent` | `!PRESETn \|-> (PSLVERR == 1'b0)` | Error outputs must be deasserted during reset. |

---

## 4. Functional Coverage Model

### 4.1 Coverpoints
1. **`cp_type`**: Operation type (`WRITE`, `READ`).
2. **`cp_addr`**: Address regions (Base, Max, Low Range, Mid Range, High Range, Out-of-bounds).
3. **`cp_strb`**: Byte strobes (`4'b0001`, `4'b0010`, `4'b0100`, `4'b1000`, `4'b0011`, `4'b1100`, `4'b1111`).
4. **`cp_resp`**: Response statuses (`OKAY`, `ERROR`).
5. **`cp_idle`**: Inter-transaction latencies (`0`, `1`, `2`, `3+`).

### 4.2 Cross Coverage
- **`cross_type_x_strb`**: Cross product of operation direction and byte strobes.
- **`cross_type_x_addr`**: Cross product of operation direction and address regions.
- **`cross_type_x_resp`**: Cross product of operation direction and protocol responses.

---

## 5. Coverage Closure Target
- **Functional Coverage**: $\ge 95\%$ across all testcases combined.
- **Code Coverage** (Line, Branch, Toggle, FSM): $100\%$ on synthesizable RTL design.
- **Assertion Coverage**: $100\%$ of all defined SVA properties exercised.
