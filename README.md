# SPI Slave Controller — Verilog

A synthesizable **SPI Slave controller implemented in Verilog HDL** using a finite-state machine (FSM).

The design supports **write transactions, read-address transactions, and read-data transactions**, while providing serial data reception through `MOSI` and serial transmission through `MISO`.

---

## 📌 Project Overview

SPI (Serial Peripheral Interface) is a synchronous serial communication protocol commonly used to connect microcontrollers, processors, sensors, memories, and other peripherals.

This project implements the **Slave side of an SPI communication interface**.

The slave monitors the `SS_n` signal to detect the beginning and end of transactions and uses an FSM to determine whether the master is performing a:

* Write operation
* Read-address operation
* Read-data operation

The received serial data is assembled into a **10-bit `rx_data` word**, while transmitted data is provided through an **8-bit `tx_data` input** and shifted out through `MISO`.

---

# 🧱 Architecture

The controller is based on a finite-state machine with five states:

```text
             SS_n = 0
        ┌────────────────┐
        │                ▼
     ┌──────┐        ┌─────────┐
     │ IDLE │───────►│ CHK_CMD │
     └──────┘        └────┬────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
           MOSI=0       READ cmd     READ cmd
              │         address       data
              ▼            │            │
          ┌───────┐        ▼            ▼
          │ WRITE │   ┌─────────┐  ┌───────────┐
          └───────┘   │ READ_ADD│  │ READ_DATA │
              │        └─────────┘  └───────────┘
              │             │            │
              └─────────────┴────────────┘
                         SS_n = 1
                              │
                              ▼
                           IDLE
```

---

# 🔄 FSM States

The FSM contains five configurable states.

| State       | Encoding | Description                                            |
| ----------- | -------- | ------------------------------------------------------ |
| `IDLE`      | `3'b000` | Waiting for SPI transaction                            |
| `WRITE`     | `3'b001` | Receiving write data                                   |
| `CHK_CMD`   | `3'b010` | Decoding the received command                          |
| `READ_ADD`  | `3'b011` | Receiving read address                                 |
| `READ_DATA` | `3'b100` | Receiving address/data while transmitting through MISO |

The state encodings are implemented as parameters:

```verilog
parameter IDLE      = 3'b000,
parameter WRITE     = 3'b001,
parameter CHK_CMD   = 3'b010,
parameter READ_ADD  = 3'b011,
parameter READ_DATA = 3'b100
```

This makes the FSM easy to modify or integrate into different designs.

---

# 🔌 Module Interface

```verilog
module SPI_Slave #(
    parameter IDLE = 3'b000,
    parameter WRITE = 3'b001,
    parameter CHK_CMD = 3'b010,
    parameter READ_ADD = 3'b011,
    parameter READ_DATA = 3'b100
)(
    input SS_n,
    input MOSI,
    input rst_n,
    input clk,
    input tx_valid,

    input [7:0] tx_data,

    output reg MISO,
    output reg rx_valid,

    output reg [9:0] rx_data
);
```

---

# 📥 Inputs

| Signal     | Width | Description                     |
| ---------- | ----: | ------------------------------- |
| `SS_n`     |     1 | Active-low Slave Select         |
| `MOSI`     |     1 | Master Out Slave In             |
| `rst_n`    |     1 | Active-low asynchronous reset   |
| `clk`      |     1 | System clock                    |
| `tx_valid` |     1 | Indicates valid transmit data   |
| `tx_data`  |     8 | Data to transmit through `MISO` |

---

# 📤 Outputs

| Signal     | Width | Description                               |
| ---------- | ----: | ----------------------------------------- |
| `MISO`     |     1 | Master In Slave Out                       |
| `rx_valid` |     1 | Indicates a complete 10-bit received word |
| `rx_data`  |    10 | Received SPI data                         |

---

# 🧠 Internal Registers

The design uses several internal registers:

```verilog
reg [2:0] current_state, next_state;
reg [3:0] counter;
reg [2:0] tx_counter;
reg read_recieved;
```

### `current_state`

Stores the current FSM state.

### `next_state`

Determines the next FSM state according to the current inputs.

### `counter`

Counts the number of received bits.

The controller receives up to **10 bits** before asserting `rx_valid`.

### `tx_counter`

Controls which bit of `tx_data` is transmitted through `MISO`.

It starts from bit 7 and decrements toward bit 0.

### `read_recieved`

Tracks whether the controller has received a read-address transaction and should subsequently enter the read-data phase.

---

# ✍️ Write Transaction

When the slave is selected:

```text
SS_n = 0
```

the FSM moves from:

```text
IDLE → CHK_CMD
```

If the command bit on `MOSI` is `0`, the controller enters:

```text
CHK_CMD → WRITE
```

The received bits are shifted into `rx_data`:

```verilog
rx_data <= {rx_data[8:0], MOSI};
```

The counter tracks the received bits.

After receiving 10 bits:

```verilog
if(counter == 9)
    rx_valid <= 1;
```

Therefore:

```text
10 received bits
       │
       ▼
rx_data updated
       │
       ▼
rx_valid = 1
```

---

# 📖 Read Transaction

A read operation begins when the command bit indicates a read:

```text
MOSI = 1
```

The FSM then checks whether a read address has already been received.

### First Read Phase

```text
CHK_CMD → READ_ADD
```

The address is received serially through `MOSI`.

After 10 bits:

```verilog
read_recieved <= 1;
rx_valid <= 1;
```

The controller records that the read address has been received.

---

# 📤 Read Data Phase

After the read address has been received, the FSM can transition into:

```text
READ_DATA
```

During this state, the controller:

1. Continues receiving data through `MOSI`.
2. Generates `rx_valid` after a complete 10-bit word.
3. Transmits `tx_data` through `MISO` when `tx_valid` is asserted.

The transmit logic is:

```verilog
if(tx_valid) begin
    MISO <= tx_data[tx_counter];
    tx_counter <= tx_counter - 1;
end
```

The transmission starts from:

```text
tx_data[7]
```

and proceeds toward:

```text
tx_data[0]
```

---

# 🔢 Serial-to-Parallel Conversion

Incoming MOSI data is converted from serial form into the 10-bit `rx_data` register.

For every received bit:

```verilog
rx_data <= {rx_data[8:0], MOSI};
```

Conceptually:

```text
MOSI
 │
 ▼
┌──────────────────────────┐
│ 10-bit Shift Register    │
│                          │
│ [9] [8] [7] ... [1] [0] │
└──────────────────────────┘
            │
            ▼
         rx_data
```

After 10 clock cycles, `rx_valid` indicates that the complete word is available.

---

# 🔀 Command Processing

The command decision is performed in `CHK_CMD`.

```verilog
if(!MOSI)
    next_state = WRITE;
else if(MOSI && read_recieved)
    next_state = READ_DATA;
else if(MOSI && !read_recieved)
    next_state = READ_ADD;
```

The behavior can be summarized as:

| Command          | `MOSI` | `read_recieved` | Next State  |
| ---------------- | -----: | --------------: | ----------- |
| Write            |    `0` |               X | `WRITE`     |
| First Read Phase |    `1` |             `0` | `READ_ADD`  |
| Read Data Phase  |    `1` |             `1` | `READ_DATA` |

---

# 🔄 Slave Select Behavior

`SS_n` is active-low.

When:

```text
SS_n = 0
```

the SPI slave is selected and remains in the current transaction state.

When:

```text
SS_n = 1
```

the transaction terminates and the FSM returns to:

```text
IDLE
```

For example:

```verilog
WRITE: begin
    if(SS_n)
        next_state = IDLE;
    else
        next_state = WRITE;
end
```

This behavior is implemented across the transaction states.

---

# ♻️ Reset

The module uses an **active-low asynchronous reset**:

```verilog
always @(posedge clk or negedge rst_n)
```

When:

```text
rst_n = 0
```

the controller returns to its initial state and clears its internal registers:

```verilog
current_state <= IDLE;
MISO <= 0;
rx_valid <= 0;
rx_data <= 0;
counter <= 0;
read_recieved <= 0;
tx_counter <= 7;
```

This guarantees a known initial state before communication begins.

---

# 📊 Transaction Flow

## Write

```text
Master
   │
   │ SS_n = 0
   ▼
SPI Slave
   │
   ▼
CHK_CMD
   │
   │ MOSI = 0
   ▼
WRITE
   │
   │ Receive 10 bits
   ▼
rx_data
   │
   ▼
rx_valid = 1
   │
   │ SS_n = 1
   ▼
IDLE
```

## Read

```text
Master
   │
   │ SS_n = 0
   ▼
CHK_CMD
   │
   │ MOSI = 1
   ▼
READ_ADD
   │
   │ Receive 10-bit address
   ▼
read_recieved = 1
   │
   ▼
READ_DATA
   │
   ├──── MOSI → rx_data
   │
   └──── tx_data → MISO
   │
   ▼
SS_n = 1
   │
   ▼
IDLE
```

---

# 🧪 Verification

The design can be verified using a Verilog/SystemVerilog testbench by testing:

### Write Transactions

* Slave selection
* Write command
* 10-bit data reception
* `rx_valid` assertion
* Correct `rx_data`

### Read Transactions

* Read command
* Address reception
* Transition from `READ_ADD` to `READ_DATA`
* Correct `tx_data` transmission
* `MISO` bit ordering

### Control Tests

* Reset behavior
* `SS_n` transaction termination
* Back-to-back transactions
* Counter behavior
* FSM transitions
* `tx_valid` handling

---

# 📁 Suggested Project Structure

```text
SPI-Slave/
│
├── RTL_Codes/
│   └── SPI_Slave.v
│
├── Testbench/
│   └── SPI_Slave_tb.v
│
├── Simulation/
│   └── ...
│
└── README.md
```

---

# 🛠️ Technologies

* **Verilog HDL**
* **RTL Design**
* **Finite State Machines**
* **SPI Protocol**
* **Serial-to-Parallel Conversion**
* **Parallel-to-Serial Conversion**
* **Digital Design**
* **FPGA Design**

---

# 🎯 Learning Objectives

This project demonstrates practical understanding of:

* SPI communication protocol
* RTL design methodology
* FSM-based protocol controllers
* State transition logic
* Sequential and combinational logic
* Serial data reception
* Serial data transmission
* Shift-register implementation
* Counters and bit tracking
* Active-low asynchronous reset
* Parameterized Verilog modules

---

## 👨‍💻 Author

**Basel Sherif**

Electronics & Communication Engineering
Cairo University

---

## ⭐ Summary

This project implements a **Verilog SPI Slave controller** using a five-state FSM.

The controller supports **write operations, read-address operations, and read-data operations**, with serial reception through `MOSI`, serial transmission through `MISO`, configurable FSM states, and status signaling through `rx_valid`.

It provides a practical RTL implementation of a common hardware communication interface and demonstrates the design of a synchronous serial protocol controller from the ground up.
