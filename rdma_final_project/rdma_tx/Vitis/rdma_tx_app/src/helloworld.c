#include <stdio.h>
#include <stdint.h>
#include <xtimer_config.h>
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xparameters.h"
#include "xiltimer.h"   // <-- timing / XTime_GetTime

// Base addresses
#ifndef DATA_MOVER_BASE
#define DATA_MOVER_BASE XPAR_DATA_MOVER_CONTROLLER_0_BASEADDR
#endif

#ifndef SQ_BUFFER_BASE
#define SQ_BUFFER_BASE 0x10000000U
#endif

#define CQ_BUFFER_BASE 0x40000000U
#define PAYLOAD_BUFFER_BASE 0x30000000U
#define REMOTE_BUFFER_BASE 0x20000000U  // Simulated "remote" memory for loopback

#define SODIRINSIK XPAR_RDMA_AXILITE_CTRL_0_BASEADDR

// Register indices
#define REG_IDX_CTRL       0
#define REG_IDX_SQ_BASE_LO 8
#define REG_IDX_SQ_BASE_HI 9
#define REG_IDX_SQ_SIZE    10
#define REG_IDX_SQ_HEAD    11 // HW-owned read-only
#define REG_IDX_SQ_TAIL    12
#define REG_IDX_SQ_DOORBELL 13
#define REG_IDX_CQ_BASE_LO 16
#define REG_IDX_CQ_BASE_HI 17
#define REG_IDX_CQ_SIZE    18
#define REG_IDX_CQ_HEAD    19
#define REG_IDX_CQ_TAIL    20 // HW-owned read-only
#define REG_IDX_CQ_DOORBELL 21

#define REG_OFFSET(idx) ((idx) * 4U)
#define REG_ADDR(idx) (DATA_MOVER_BASE + REG_OFFSET(idx))

#define BRAM_BASE_ADDR XPAR_AXI_BRAM_CTRL_0_BASEADDR
#define OFFSET_SRC_MAC_L 0x00
#define OFFSET_SRC_MAC_H 0x04
#define OFFSET_DST_MAC_L 0x08
#define OFFSET_DST_MAC_H 0x0C

// Helpers for throughput calculation
#ifndef COUNTS_PER_SECOND
// Normally defined by BSP (xtime/xiltimer); if not, define it manually.
#warning "COUNTS_PER_SECOND not defined by BSP; define it to your timer frequency."
#define COUNTS_PER_SECOND XPAR_PSU_PSS_REF_CLK_FREQ_HZ
#endif

#define BYTES_TO_MB(b)        ((double)(b) / (1024.0 * 1024.0))
#define COUNTS_TO_SECONDS(c)  ((double)(c) / (double)COUNTS_PER_SECOND)

// SQ Entry structure (64 bytes) - matches slave stream parser
typedef struct {
    uint32_t id;              // Word 0: WQE ID (rdma_id)
    uint16_t opcode;          // Word 1 [15:0]: RDMA opcode (rdma_opcode)
    uint16_t flags;           // Word 1 [31:16]: Flags (rdma_flags)
    uint64_t local_key;       // Words 2-3: Local DDR address (rdma_local_key) - bytes 8-15
    uint64_t remote_key;      // Words 4-5: Remote address (rdma_remote_key) - bytes 16-23
    uint32_t length_lo;       // Word 6: Transfer length lower 32 bits (rdma_btt[31:0]) - bytes 24-27
    uint32_t length_hi;       // Word 7: Transfer length upper 32 bits (rdma_btt[63:32]) - bytes 28-31
    uint32_t reserved[8];     // Words 8-15: Reserved (rdma_btt upper + rdma_reserved) - bytes 32-63
} sq_entry_t;

// CQ Entry structure (32 bytes)
typedef struct {
    uint32_t wqe_id;          // Word 0: SQ index that completed
    uint32_t status_opcode;   // Word 1: Status[7:0] | Opcode[15:8] | Reserved[31:16]
    uint32_t bytes_sent_lo;   // Word 2: Bytes transferred (lower 32 bits)
    uint32_t bytes_sent_hi;   // Word 3: Bytes transferred (upper 32 bits)
    uint32_t original_id;     // Word 4: Original WQE ID
    uint32_t original_length; // Word 5: Original requested length
    uint32_t reserved1;       // Word 6: Reserved
    uint32_t reserved2;       // Word 7: Reserved
} cq_entry_t;

void print_sq_entry(uint32_t idx, volatile sq_entry_t *entry) {
    xil_printf("\n=== SQ Entry %u at 0x%08x ===\n", idx, (unsigned)entry);
    xil_printf("  ID:         0x%08x\n", entry->id);
    xil_printf("  Opcode:     0x%04x\n", entry->opcode);
    xil_printf("  Flags:      0x%04x\n", entry->flags);
    xil_printf("  Local Key:  0x%08x%08x\n", 
               (unsigned)(entry->local_key >> 32), (unsigned)(entry->local_key & 0xFFFFFFFF));
    xil_printf("  Remote Key: 0x%08x%08x\n",
               (unsigned)(entry->remote_key >> 32), (unsigned)(entry->remote_key & 0xFFFFFFFF));
    xil_printf("  Length:     0x%08x%08x (%u bytes)\n",
               entry->length_hi, entry->length_lo, entry->length_lo);
}

void print_cq_entry(uint32_t idx, volatile cq_entry_t *entry) {
    xil_printf("\n=== CQ Entry %u at 0x%08x ===\n", idx, (unsigned)entry);
    xil_printf("  WQE ID:          0x%08x\n", entry->wqe_id);
    xil_printf("  Status:          0x%02x\n", (unsigned)(entry->status_opcode & 0xFF));
    xil_printf("  Opcode:          0x%02x\n", (unsigned)((entry->status_opcode >> 8) & 0xFF));
    xil_printf("  Bytes Sent:      0x%08x%08x (%u bytes)\n",
               entry->bytes_sent_hi, entry->bytes_sent_lo, entry->bytes_sent_lo);
    xil_printf("  Original ID:     0x%08x\n", entry->original_id);
    xil_printf("  Original Length: %u bytes\n", entry->original_length);
}

void SetupMacAddress(){
    u32 src_mac_l = 0x35010203;
    u32 src_mac_h = 0x0000000A;

    u32 dst_mac_l = 0x2915372C;
    u32 dst_mac_h = 0x0000000C;

    xil_printf("Writing mac addresses to 0x%08x \r\n", BRAM_BASE_ADDR);

    Xil_Out32(BRAM_BASE_ADDR+OFFSET_SRC_MAC_L , src_mac_l);
    Xil_Out32(BRAM_BASE_ADDR+OFFSET_SRC_MAC_H , src_mac_h);
    Xil_Out32(BRAM_BASE_ADDR+OFFSET_DST_MAC_L , dst_mac_l);
    Xil_Out32(BRAM_BASE_ADDR+OFFSET_DST_MAC_H , dst_mac_h);

    xil_printf("mac config complete \r\n");
    
    u32 check_src = Xil_In32(BRAM_BASE_ADDR + OFFSET_SRC_MAC_L);

    if(check_src != src_mac_l){
        xil_printf("Error, bram write failed. Read: 0x%08x\r\n", check_src);
    } else {
        xil_printf("bram write success \r\n");
    }
}

// static int configure_tx(u16 payload_len)
// {
//     /* Enable the encapsulator */
//     Xil_Out32(SODIRINSIK + 0x00 , 0x1);  //enable
//     Xil_Out32(SODIRINSIK + 0x08 , payload_len + 8); //payloadlength
//     Xil_Out32(SODIRINSIK + 0x0c , 0xAC1F09CA); // src ip
//     Xil_Out32(SODIRINSIK + 0x10 , 0xAC1F09C9); //dst ip
//     Xil_Out32(SODIRINSIK + 0x14 , 0xCE06); // src port
//     Xil_Out32(SODIRINSIK + 0x18 , 0x138D); // dst port
//     Xil_Out32(SODIRINSIK + 0x00 , 0x3); //enable + start
//     return 0;
// }

int main(void) {

    xil_printf("\n========================================\n");
    xil_printf("  RDMA Loopback TX->RX Test\n");
    xil_printf("========================================\n\n");

    // Initialize buffers
    volatile sq_entry_t *sq_buf = (volatile sq_entry_t *)SQ_BUFFER_BASE;
    volatile cq_entry_t *cq_buf = (volatile cq_entry_t *)CQ_BUFFER_BASE;
    volatile uint32_t *payload_buf = (volatile uint32_t *)PAYLOAD_BUFFER_BASE;
    volatile uint32_t *remote_buf = (volatile uint32_t *)REMOTE_BUFFER_BASE;

    // Clear SQ buffer
    for (uint32_t i = 0; i < 16 * 16; ++i) {
        ((volatile uint32_t *)sq_buf)[i] = 0xffffffff;
    }

    // Clear CQ buffer
    for (uint32_t i = 0; i < 16 * 8; ++i) {
        ((volatile uint32_t *)cq_buf)[i] = 0xffffffff;
    }

    // Clear remote buffer (this will be the RX destination)
    xil_printf("Clearing remote buffer at 0x%08x...\n", (unsigned)REMOTE_BUFFER_BASE);
    for (uint32_t i = 0; i < 4096; ++i) {
        remote_buf[i] = 0x00000000U;
    }
    Xil_DCacheFlushRange((UINTPTR)remote_buf, 16384);
    xil_printf("Remote buffer cleared (destination for RX)\n");

    // Prepare payload data with unique patterns for each test
    xil_printf("Preparing payload buffer at 0x%08x...\n", (unsigned)PAYLOAD_BUFFER_BASE);
    for (uint32_t i = 0; i < 4096*64; ++i) {
        payload_buf[i] = 0xDEAD0000U | i;
    }
    // flush full 16 KiB payload buffer (4096 * 4)
    Xil_DCacheFlushRange((UINTPTR)payload_buf, 4096*64*4);
    xil_printf("Payload prepared: pattern 0xDEADxxxx\n");

    // Configure IP registers
    xil_printf("\nConfiguring RDMA controller...\n");
    Xil_Out32(REG_ADDR(REG_IDX_SQ_BASE_LO), (uint32_t)(SQ_BUFFER_BASE & 0xFFFFFFFFU));
    Xil_Out32(REG_ADDR(REG_IDX_SQ_BASE_HI), 0U);
    Xil_Out32(REG_ADDR(REG_IDX_SQ_SIZE), 4);
    Xil_Out32(REG_ADDR(REG_IDX_CQ_BASE_LO), (uint32_t)(CQ_BUFFER_BASE & 0xFFFFFFFFU));
    Xil_Out32(REG_ADDR(REG_IDX_CQ_BASE_HI), 0U);
    Xil_Out32(REG_ADDR(REG_IDX_CQ_SIZE), 4);

    // Initialize head/tail pointers
    Xil_Out32(REG_ADDR(REG_IDX_SQ_TAIL), 0U);
    Xil_Out32(REG_ADDR(REG_IDX_CQ_HEAD), 0U);

    xil_printf("  SQ: base=0x%08x, size=4\n", (unsigned)SQ_BUFFER_BASE);
    xil_printf("  CQ: base=0x%08x, size=4\n", (unsigned)CQ_BUFFER_BASE);

    // Enable global control
    uint32_t ctrl = Xil_In32(REG_ADDR(REG_IDX_CTRL));
    ctrl |= 0x1U; // GLOBAL_ENABLE
    Xil_Out32(REG_ADDR(REG_IDX_CTRL), ctrl);
    xil_printf("  Global enable set\n");

    // Verify initial state
    uint32_t sq_head = Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD));
    uint32_t cq_tail = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));
    xil_printf("\nInitial state:\n");
    xil_printf("  SQ_HEAD: %u\n", sq_head);
    xil_printf("  SQ_TAIL: 0\n");
    xil_printf("  CQ_HEAD: 0\n");
    xil_printf("  CQ_TAIL: %u\n", cq_tail);

    // Create test SQ entries
    xil_printf("\n========================================\n");
    xil_printf("Creating test SQ entries...\n");
    xil_printf("========================================\n");

    // Test 1
    sq_buf[0].id = 0x00010001;
    sq_buf[0].opcode = 0x0001; // RDMA_WRITE
    sq_buf[0].flags = 0x0000;
    sq_buf[0].local_key = PAYLOAD_BUFFER_BASE; // Source: 0x30000000
    sq_buf[0].remote_key = REMOTE_BUFFER_BASE; // Destination: 0x20000000
    sq_buf[0].length_lo = 4096;
    sq_buf[0].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[0].reserved[i] = 0;
    print_sq_entry(0, &sq_buf[0]);

    // Test 2
    sq_buf[1].id = 0x00020002;
    sq_buf[1].opcode = 0x0001;
    sq_buf[1].flags = 0x0000;
    sq_buf[1].local_key = PAYLOAD_BUFFER_BASE + 0x1000;
    //sq_buf[1].local_key = PAYLOAD_BUFFER_BASE + 0x0040; // Source offset
    sq_buf[1].remote_key = REMOTE_BUFFER_BASE + 0x1000;
    sq_buf[1].length_lo = 4096;
    sq_buf[1].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[1].reserved[i] = 0;
    print_sq_entry(1, &sq_buf[1]);

    // Test 3
    sq_buf[2].id = 0x00030003;
    sq_buf[2].opcode = 0x0001;
    sq_buf[2].flags = 0x0000;
    sq_buf[2].local_key = PAYLOAD_BUFFER_BASE + 0x2000;
    //sq_buf[2].local_key = PAYLOAD_BUFFER_BASE + 0x0080;
    sq_buf[2].remote_key = REMOTE_BUFFER_BASE + 0x2000;
    sq_buf[2].length_lo = 4096;
    sq_buf[2].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[2].reserved[i] = 0;
    print_sq_entry(2, &sq_buf[2]);

    // Test 4
    sq_buf[3].id = 0x00040004;
    sq_buf[3].opcode = 0x0001;
    sq_buf[3].flags = 0x0000;
    sq_buf[3].local_key = PAYLOAD_BUFFER_BASE + 0x3000;
    //sq_buf[3].local_key = PAYLOAD_BUFFER_BASE + 0x00c0;
    sq_buf[3].remote_key = REMOTE_BUFFER_BASE + 0x3000;
    sq_buf[3].length_lo = 4096;
    sq_buf[3].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[3].reserved[i] = 0;
    print_sq_entry(3, &sq_buf[3]);

    // Flush SQ entries to DDR
    Xil_DCacheFlushRange((UINTPTR)sq_buf, 128 * 8);
    xil_printf("\nSQ entries flushed to DDR\n");

    // Submit entries by updating SQ_TAIL
    xil_printf("\n========================================\n");
    xil_printf("Submitting SQ entries...\n");
    xil_printf("========================================\n");
    XTime tStart, tEnd;
        XTime_GetTime(&tStart);
    for (uint32_t test_idx = 0; test_idx < 16; ++test_idx) {
        uint32_t entry_idx = test_idx & 0x3; // reuse 4 descriptors in ring

        
        uint32_t sq_tail_before = Xil_In32(REG_ADDR(REG_IDX_SQ_TAIL));
        uint32_t sq_head_before = Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD));
        uint32_t cq_tail_before = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));

        uint32_t new_tail = (sq_tail_before + 1) % 4;

        // --- Start timing: from SQ doorbell to CQ completion ---
        

        Xil_Out32(REG_ADDR(REG_IDX_SQ_TAIL), new_tail);

        // Poll for SQ_HEAD advancement (optional progress info)
        const uint32_t timeout = 1000000;
        uint32_t poll_count = 0;
        uint32_t sq_head_after = sq_head_before;

        while (poll_count < timeout) {
            sq_head_after = Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD));
            if (sq_head_after != sq_head_before) {
                break;
            }
            poll_count++;
        }

        if (sq_head_after == sq_head_before) {
            xil_printf("TIMEOUT: SQ_HEAD stuck at %u after %u polls\n",
                       sq_head_after, poll_count);
        }

        // Check CQ_TAIL advancement
        uint32_t cq_tail_after = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));

        // Invalidate CQ buffer itself

        if (cq_tail_after != cq_tail_before) {
            // --- Stop timing at first observed CQ tail change ---
            // --- Stop timing at first observed CQ tail change ---
            Xil_Out32(REG_ADDR(REG_IDX_CQ_HEAD), cq_tail_after);
        } else {
            xil_printf("WARNING: CQ_TAIL did not advance (still %u)\n", cq_tail_after);
        }

        xil_printf("\n");
    }
    XTime_GetTime(&tEnd);
XTime delta = tEnd - tStart;

// Use 64-bit integers for the math
u64 delta_cycles = (u64)delta;
u32 bytes = sq_buf[0].length_lo*4*32768;

// Time in microseconds: us = delta * 1e6 / COUNTS_PER_SECOND
u64 us = (delta_cycles * 1000000ULL) / (u64)XPAR_PSU_PSS_REF_CLK_FREQ_HZ;

// Throughput in MB/s (fixed-point, x1000):
// MB/s = bytes / (1024^2) / seconds
//      = bytes * COUNTS_PER_SECOND / (delta * 1024^2)
u64 thr_x1000 = 0;
if (delta_cycles != 0) {
    thr_x1000 = ((u64)bytes * (u64)XPAR_PSU_PSS_REF_CLK_FREQ_HZ * 1000ULL) /
                (delta_cycles * 1024ULL * 1024ULL);
}
u32 thr_int  = (u32)(thr_x1000 / 1000ULL);   // integer part
u32 thr_frac = (u32)(thr_x1000 % 1000ULL);   // 3 decimal digits

xil_printf("TIMING: Δcycles=%llu, Δt=%u us, bytes=%u, throughput=%u.%03u MB/s\r\n",
           (unsigned long long)delta_cycles,
           (u32)us,
           bytes,
           thr_int,
           thr_frac);
            // Update CQ_HEAD to acknowledge completion
            

    xil_printf("\n========================================\n");
    xil_printf("RDMA TX->RX Test Complete\n");
    xil_printf("========================================\n\n");
}
