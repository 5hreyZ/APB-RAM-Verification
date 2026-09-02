# Architecture Specification: AMBA APB RAM Controller & DV Environment

This document provides a detailed architectural specification of the synthesizable **AMBA APB4 Slave RAM Memory Controller** and its **SystemVerilog Object-Oriented Verification Environment**.

---

## 1. System Overview

The AMBA Advanced Peripheral Bus (APB) is an energy-efficient, low-complexity bus protocol optimized for peripheral and memory interfaces in SoC designs. This project implements an APB4-compliant slave memory controller with byte-enable write masking, zero-wait-state memory access, and address decoding with error detection.

```
+-----------------------------------------------------------------------------------+
|                                   SoC Interconnect                                |
+-----------------------------------------------------------------------------------+
                                          |
                              AMBA APB4 Master Interface
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        APB Slave RAM Controller (DUT)                             |
|                                                                                   |
|  +---------------------------+       +-----------------------------------------+  |
|  |     Protocol FSM &        |       |        Address Decoder & Error Unit     |  |
|  |     Handshake Engine      | ----> | - Bounds check: [BASE_ADDR, BASE+SIZE-1]|  |
|  |  (IDLE -> SETUP -> ACCESS)|       | - Alignment check: PADDR[1:0] == 2'b00  |  |
|  +---------------------------+       | - PSLVERR generation                    |  |
|               |                      +-----------------------------------------+  |
|               |                                           |                       |
|               v                                           v                       |
|  +-----------------------------------------------------------------------------+  |
|  |                     Byte-Addressable Memory Array Core                      |  |
|  |       - 1024 x 32-bit (4 KB Total Capacity)                                 |  |
|  |       - 4 Independent Byte Lanes (PSTRB[3:0] write masking)                 |  |
|  |       - Combinational read output / Synchronous clocked write               |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 2. RTL Design Architecture

### 2.1 Interface Signal Definitions

| Signal | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `PCLK` | Input | 1 | APB Bus Synchronous Clock. All signals sampled on rising edge. |
| `PRESETn` | Input | 1 | Active-low Asynchronous Reset. |
| `PSEL` | Input | 1 | Slave Select. Initiates transfer when high. |
| `PENABLE` | Input | 1 | APB Strobe. Asserted in ACCESS phase. |
| `PWRITE` | Input | 1 | Direction: `1` = Write, `0` = Read. |
| `PADDR` | Input | 32 | Byte Address bus. |
| `PWDATA` | Input | 32 | Write Data bus. |
| `PSTRB` | Input | 4 | Byte Strobes (Write Enables for individual bytes in 32-bit word). |
| `PPROT` | Input | 3 | Protection attributes (Privilege, Security, Instruction/Data). |
| `PREADY` | Output | 1 | Transfer Handshake Ready signal. |
| `PRDATA` | Output | 32 | Read Data bus output to master. |
| `PSLVERR` | Output | 1 | Slave Error indicator (Asserted on invalid access). |

### 2.2 Address Decoding & Byte-Enable Masking

The RAM controller decodes addresses based on configurable parameters:
$$\text{Memory Size (Bytes)} = \text{MEM\_DEPTH} \times 4 = 1024 \times 4 = 4096 \text{ Bytes (4 KB)}$$
$$\text{Valid Address Range} = [\text{BASE\_ADDR}, \text{BASE\_ADDR} + 4095]$$

- **Alignment**: Addresses must be 4-byte aligned (`PADDR[1:0] == 2'b00`).
- **Error Assertion**: If an access falls outside the range or is unaligned, the slave sets `PSLVERR = 1` during the ACCESS phase.
- **Byte Masking (`PSTRB`)**:
  - `PSTRB[0] == 1` $\rightarrow$ Write `PWDATA[7:0]` to byte 0 of target word.
  - `PSTRB[1] == 1` $\rightarrow$ Write `PWDATA[15:8]` to byte 1 of target word.
  - `PSTRB[2] == 1` $\rightarrow$ Write `PWDATA[23:16]` to byte 2 of target word.
  - `PSTRB[3] == 1` $\rightarrow$ Write `PWDATA[31:24]` to byte 3 of target word.

---

## 3. Verification Environment Architecture

The testbench uses a modular, layered Object-Oriented Architecture:

```
+-----------------------------------------------------------------------------------+
|                                 Verification Environment                          |
|                                                                                   |
|  +--------------------+         Mailbox         +-------------------------------+ |
|  |   apb_generator    | ----------------------> |          apb_driver           | |
|  | (Random/Directed)  |                         |  - SETUP -> ACCESS phases     | |
|  +--------------------+                         |  - Clock-synchronous driving  | |
|                                                 +-------------------------------+ |
|                                                                 |                 |
|                                                          apb_if (Virtual IF)      |
|                                                                 |                 |
|                                                                 v                 |
|  +--------------------+         Mailbox         +-------------------------------+ |
|  |   apb_scoreboard   | <---------------------- |          apb_monitor          | |
|  | - Ref memory model |                         |  - Passive bus observation    | |
|  | - Data checking    | <------+                |  - Handshake sampling         | |
|  +--------------------+        |                +-------------------------------+ |
|                                | Mailbox                        |                 |
|  +--------------------+        |                                |                 |
|  |    apb_coverage    | <------+                                |                 |
|  | - Covergroups      |                                         |                 |
|  | - Cross coverage   |                                         |                 |
|  +--------------------+                                         |                 |
|                                                                 v                 |
|                                                      +---------------------+      |
|                                                      |     DUT / SVA       |      |
|                                                      +---------------------+      |
+-----------------------------------------------------------------------------------+
```

### 3.1 Verification Component Responsibilities
1. **`apb_transaction`**: Data packet model containing randomized address, data, operation type, byte strobes, idle delays, and error flags.
2. **`apb_generator`**: Produces random or sequence-driven transaction streams and synchronizes with driver handshakes.
3. **`apb_driver`**: Translates high-level transaction items into cycle-accurate APB bus transfers via interface clocking blocks.
4. **`apb_monitor`**: Observes bus handshakes passively, converts pin transitions into transaction objects, and multicasts them.
5. **`apb_scoreboard`**: Implements an associative array golden reference model to verify data integrity and error assertions.
6. **`apb_coverage`**: Tracks functional coverage metrics across address spaces, byte strobes, transfer types, and cross-combinations.
7. **`apb_sva`**: SystemVerilog Assertions running concurrently to catch protocol violations immediately.
