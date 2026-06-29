# FPGA-Based Ethernet Load Balancer

A hardware-accelerated Ethernet Load Balancer implemented on FPGA using Verilog HDL. This project parses Ethernet packets, extracts network-layer information, and distributes traffic among multiple backend servers using several load balancing algorithms.

> **Capstone Project – Computer Engineering**

---

## Overview

Modern data centers and 5G infrastructures require low-latency and high-throughput packet processing. Software-based load balancers may become performance bottlenecks under heavy traffic, while FPGA provides deterministic processing with high parallelism.

This project implements an Ethernet load balancer entirely in hardware. Incoming Ethernet frames are parsed, protocol headers are analyzed, and packets are forwarded to one of four backend servers according to the selected scheduling algorithm.

---

## Features

* Ethernet frame parsing
* IPv4 packet processing
* UDP header extraction
* AXI4-Stream based packet pipeline
* Hardware FIFO buffering
* Backend server interfaces
* Multiple load balancing algorithms

  * Round Robin (RR)
  * Consistent Hash Processor (CHP)
  * TLCM Dynamic Load Balancing
* RTL simulation

---

## System Architecture

---

## Load Balancing Algorithms

### Round Robin (RR)

Distributes packets sequentially across all available backend servers.

**Advantages**

* Simple hardware implementation
* Uniform traffic distribution
* Minimal resource utilization

---

### Consistent Hash Processor (CHP)

Maps each network flow to a backend server using a hash function, preserving flow affinity.

**Advantages**

* Stable server assignment
* Reduced flow remapping
* Suitable for stateful services

---

### The Least Connection Method (TLCM)

Implements dynamic load balancing based on server conditions and connection status.

**Advantages**

* Adaptive traffic distribution
* Improved load balancing efficiency
* Better utilization of backend resources

---


## AXI4-Stream Interface

The packet processing pipeline uses AXI4-Stream.

### Input

* `tdata`
* `tkeep`
* `tvalid`
* `tready`
* `tlast`

### Output

* `tdata`
* `tkeep`
* `tvalid`
* `tready`
* `tlast`

---

## Performance Evaluation

The system can be evaluated using the following metrics:

* Packet latency
* Throughput
* Load distribution
* Resource utilization
* Maximum operating frequency

---

## Development Environment

| Item          | Description                 |
| ------------- | --------------------------- |
| HDL           | Verilog                     |
| Platform      | FPGA                        |
| Interface     | AXI4-Stream                  |
| Simulation    | Vivado Simulator / ModelSim |
| Design Method | RTL                         |

---


## Author

**Mai Duc Khiem, Huynh Dich, Mai Thanh Hoang**

Capstone Project

Faculty of Computer Engineering

---

## License

This project is intended for educational and research purposes.
