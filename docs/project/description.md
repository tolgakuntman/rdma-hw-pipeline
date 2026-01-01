# RDMA Engine on Kria KR260

## Overview

This project implements a custom RDMA Engine on the Xilinx Kria KR260 FPGA platform, targeting high-throughput, low-latency data movement between host memory and a physical Ethernet network interface.

The system is designed as a fully hardware-driven data path that minimizes CPU involvement by offloading packet handling, queue management, and bulk memory transfers into FPGA logic. It follows the architectural principles of RDMA systems while remaining lightweight, modular, and suitable for experimental validation on a single FPGA platform.

The final design integrates RDMA queue logic, IP/UDP packetization, and a real Ethernet MAC/PHY subsystem, enabling end-to-end data transfers over a standard Gigabit Ethernet link.

> **Getting Started:** For build instructions and quick start guide, see the [project README](https://github.com/your-repo/team-h/blob/main/README.md) in the repository root.

---


### Part 1 — RDMA Core & Queue Engine

Implements submit and completion queues, descriptor fetching, execution control, and coordination of DDR memory transfers via the AXI DataMover. This part defines the execution semantics of the system and enforces ordering, ownership, and completion guarantees.

### Part 2 — Network Packetization Layer (IP/UDP)

Responsible for constructing and parsing Ethernet-compatible IP/UDP packets. This layer bridges the RDMA core and the Ethernet subsystem by converting streaming payload data into valid network frames and extracting RDMA headers and payloads from received packets.

### Part 3 — Ethernet MAC & PHY Subsystem

Implements the physical network interface using the AXI 1G/2.5G Ethernet Subsystem, RGMII signaling, and an external Gigabit PHY. This part handles MAC configuration, PHY management via MDIO, AXI-Stream TX/RX behavior, and reliable delivery of frames to and from the FPGA fabric.

Each part is developed and validated independently before being integrated into the final end-to-end system.

---

## Team Responsibilities

The CPU configures the system and submits work descriptors, but all data movement and protocol handling occur in hardware.

![Project Flow](RDMA_logic/images/project_flow.png)
*Figure: End-to-end system data flow from RDMA queue submission through IP/UDP packetization to Ethernet transmission*

---

## Our Team:
| Member            | Project Part | Responsibility                                             |
| ----------------- | ------------ | ---------------------------------------------------------- |
| Tolga Kuntman    | Part 1       | RDMA Core & Queue Engine            |
| Tubi Soyer      | Part 2       | IP/UDP packetization and decapsulation logic               |
| Emir Yalcin | Part 3       | Ethernet MAC/PHY subsystem and low-level TX/RX integration |

