# AMBA APB4 Protocol Timing Diagrams

This document details the cycle-accurate timing relationships of the AMBA APB4 protocol implemented and verified in this controller.

---

## 1. APB Write Transfer (Zero Wait States)

In a basic write transfer with zero wait states:
- **T1 (SETUP Phase)**: Master drives `PADDR`, `PWDATA`, `PWRITE=1`, `PSTRB`, and asserts `PSEL=1`. `PENABLE` is deasserted (`0`).
- **T2 (ACCESS Phase)**: Master asserts `PENABLE=1`. Slave asserts `PREADY=1`. Memory write occurs on rising clock edge of T3.
- **T3 (COMPLETE / IDLE)**: `PENABLE` and `PSEL` deassert (or immediately start next transfer if back-to-back).

```text
Clock Cycle:       T1 (Setup)         T2 (Access)        T3 (Idle/Next)
                   ____               ____               ____
PCLK        ______|    |_____________|    |_____________|    |__________

PSEL        ____________/===============================\_______________
                   _____
PENABLE     ______|     \_______________________________/_______________
                                     ___________________
PWRITE      ____________/===============================\_______________

PADDR       ------------<============ Addr =============>---------------

PWDATA      ------------<============ Data =============>---------------

PSTRB       ------------<============ Strb =============>---------------
                                     ___________________
PREADY      ________________________/                   \_______________

PSLVERR     ____________________________________________________________
```

---

## 2. APB Read Transfer (Zero Wait States)

In a basic read transfer with zero wait states:
- **T1 (SETUP Phase)**: Master drives `PADDR`, `PWRITE=0`, asserts `PSEL=1`. `PENABLE=0`.
- **T2 (ACCESS Phase)**: Master asserts `PENABLE=1`. Slave drives `PRDATA` from memory and asserts `PREADY=1`.
- **T3 (COMPLETE)**: Master captures `PRDATA` on rising clock edge at end of T2.

```text
Clock Cycle:       T1 (Setup)         T2 (Access)        T3 (Idle/Next)
                   ____               ____               ____
PCLK        ______|    |_____________|    |_____________|    |__________

PSEL        ____________/===============================\_______________
                                     ___________________
PENABLE     ________________________/                   \_______________

PWRITE      ____________________________________________________________ (Low)

PADDR       ------------<============ Addr =============>---------------
                                     ___________________
PREADY      ________________________/                   \_______________

PRDATA      ------------------------<=========== RData =========>-------

PSLVERR     ____________________________________________________________
```

---

## 3. APB Transfer with Wait States (PREADY Low Extension)

When `WAIT_CYCLES > 0`, the slave deasserts `PREADY` during the ACCESS phase. Master must hold `PADDR`, `PWDATA`, `PWRITE`, and `PSTRB` completely stable until `PREADY` is sampled high.

```text
Clock Cycle:       T1 (Setup)       T2 (Wait 1)      T3 (Wait 2)      T4 (Access Done)
                   ____             ____             ____             ____
PCLK        ______|    |___________|    |___________|    |___________|    |_______

PSEL        __________/===================================================\___

PENABLE     ______________________/=======================================\___

PADDR       ----------<================== Stable Addr ====================>---

PWDATA      ----------<================== Stable Data ====================>---
                                                                      ____
PREADY      _________________________________________________________/    \___
```

---

## 4. APB Error Response (PSLVERR)

When an invalid transfer occurs (out-of-bounds address or unaligned address), the slave asserts `PSLVERR=1` alongside `PREADY=1` during the ACCESS phase.

```text
Clock Cycle:       T1 (Setup)         T2 (Access)        T3 (Idle)
                   ____               ____               ____
PCLK        ______|    |_____________|    |_____________|    |__________

PSEL        ____________/===============================\_______________
                                     ___________________
PENABLE     ________________________/                   \_______________

PADDR       ------------<======== Invalid Addr =========>---------------
                                     ___________________
PREADY      ________________________/                   \_______________
                                     ___________________
PSLVERR     ________________________/                   \_______________ (Error High)
```
