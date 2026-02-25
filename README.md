# APB-based Memory (RAM) Design and Verification

## Overview
This project implements a memory-mapped RAM peripheral compliant with the AMBA APB (Advanced Peripheral Bus) protocol. The design focuses on RTL development and functional verification using a modular SystemVerilog testbench. The goal is to demonstrate SoC-level design and verification skills, including bus protocol implementation, constrained-random testing, and scoreboard-based validation.

The APB RAM is designed as a reusable IP block that can be integrated into larger SoC environments.

---

## Key Features
- AMBA APB-compliant slave interface
- Memory-mapped RAM design in Verilog HDL
- Address decoding and read/write control logic
- Low-latency APB handshake implementation
- Modular SystemVerilog verification environment
- Constrained-random stimulus generation
- Functional correctness validation using scoreboard
- Protocol compliance and corner-case testing

---

## Architecture Overview

The system consists of an APB interface wrapped around a synchronous RAM module.

### High-level Architecture

CPU / Master
|
| APB Bus
|
APB Slave Interface
|
| Control and Address Decode
|
Memory (RAM)

---

## APB Protocol

The design follows the AMBA APB protocol, which is widely used for low-power and low-complexity peripheral communication in modern SoCs.

### Key APB Signals
- `PADDR` – Address
- `PWDATA` – Write data
- `PRDATA` – Read data
- `PWRITE` – Read/Write control
- `PSEL` – Peripheral select
- `PENABLE` – Transfer enable
- `PREADY` – Ready signal

### Transfer Phases
1. Setup phase
2. Access phase

---

## Design Details

### Memory Design
- Parameterized RAM size and data width
- Synchronous memory access
- Support for read and write transactions
- Memory-mapped peripheral behavior

### APB Slave Interface
- Protocol-compliant handshake
- Address decoding and register control
- Support for back-to-back transfers
- Ready signal management

---

## Verification Strategy

The verification environment is implemented using SystemVerilog and follows an industry-style modular architecture.

### Testbench Components

#### Generator
- Produces constrained-random read and write transactions
- Ensures coverage of address space and data patterns

#### Driver
- Converts high-level transactions into APB protocol signals
- Drives DUT inputs

#### Monitor
- Observes APB transactions
- Collects read/write activity

#### Scoreboard
- Compares expected vs actual memory behavior
- Detects mismatches and protocol violations

---

## Verification Goals
- Functional correctness
- Protocol compliance
- Random and corner-case testing
- Address boundary checks
- Data integrity validation

---

## Simulation and Validation
- Functional simulation
- Waveform analysis
- Protocol timing verification
- Stress testing using random transactions

Results, coverage metrics, and waveform screenshots will be added after full verification.

---

## Applications
- SoC peripheral design
- Embedded memory interfaces
- Low-power hardware systems
- Verification methodology learning
- IP development for ASIC and FPGA

---

## Future Enhancements
- Support for burst transfers (AXI-based upgrade)
- Formal verification
- Coverage-driven verification
- Integration with UVM
- Low-power optimization
- Clock gating and power-aware design


---

## Author
**Shrey Painuli**  
M.Tech, Sensors and Internet of Things  
Indian Institute of Technology Jodhpur
