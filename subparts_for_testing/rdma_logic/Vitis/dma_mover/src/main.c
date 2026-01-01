#include <stdio.h>
#include <stdint.h>
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xparameters.h"

// Base addresses
#ifndef DATA_MOVER_BASE
#define DATA_MOVER_BASE XPAR_DATA_MOVER_CONTROLLER_0_BASEADDR
#endif

#ifndef SQ_BUFFER_BASE
#define SQ_BUFFER_BASE 0x10000000U
#endif

#define CQ_BUFFER_BASE 0x20000000U
#define PAYLOAD_BUFFER_BASE 0x30000000U
#define REMOTE_BUFFER_BASE 0x40000000U  // Simulated "remote" memory for loopback

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
    for (uint32_t i = 0; i < 2048; ++i) {
        payload_buf[i] = 0xDEAD0000U | i;
    }
    Xil_DCacheFlushRange((UINTPTR)payload_buf, 8192);
    xil_printf("Payload prepared: pattern 0xDEADxxxx\n");

    // Configure IP registers
    xil_printf("\nConfiguring RDMA controller...\n");
    Xil_Out32(REG_ADDR(REG_IDX_SQ_BASE_LO), (uint32_t)(SQ_BUFFER_BASE & 0xFFFFFFFFU));
    Xil_Out32(REG_ADDR(REG_IDX_SQ_BASE_HI), 0U);
    Xil_Out32(REG_ADDR(REG_IDX_SQ_SIZE), 8);
    Xil_Out32(REG_ADDR(REG_IDX_CQ_BASE_LO), (uint32_t)(CQ_BUFFER_BASE & 0xFFFFFFFFU));
    Xil_Out32(REG_ADDR(REG_IDX_CQ_BASE_HI), 0U);
    Xil_Out32(REG_ADDR(REG_IDX_CQ_SIZE), 8);

    // Initialize head/tail pointers
    Xil_Out32(REG_ADDR(REG_IDX_SQ_TAIL), 0U);
    Xil_Out32(REG_ADDR(REG_IDX_CQ_HEAD), 0U);

    xil_printf("  SQ: base=0x%08x, size=8\n", (unsigned)SQ_BUFFER_BASE);
    xil_printf("  CQ: base=0x%08x, size=8\n", (unsigned)CQ_BUFFER_BASE);

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

    // Test 1: Small transfer (256 bytes) - offset 0x0000
    sq_buf[0].id = 0x00010001;
    sq_buf[0].opcode = 0x0001; // RDMA_WRITE
    sq_buf[0].flags = 0x0000;
    sq_buf[0].local_key = PAYLOAD_BUFFER_BASE; // Source: 0x30000000
    sq_buf[0].remote_key = REMOTE_BUFFER_BASE; // Destination: 0x40000000
    sq_buf[0].length_lo = 256;
    sq_buf[0].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[0].reserved[i] = 0;
    print_sq_entry(0, &sq_buf[0]);

    // Test 2: Medium transfer (512 bytes) - offset 0x1000
    sq_buf[1].id = 0x00020002;
    sq_buf[1].opcode = 0x0001;
    sq_buf[1].flags = 0x0000;
    sq_buf[1].local_key = PAYLOAD_BUFFER_BASE + 256; // Source offset
    sq_buf[1].remote_key = REMOTE_BUFFER_BASE + 0x1000; // Destination: 0x40001000
    sq_buf[1].length_lo = 512;
    sq_buf[1].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[1].reserved[i] = 0;
    print_sq_entry(1, &sq_buf[1]);

    // Test 3: Medium transfer (512 bytes) - offset 0x2000
    sq_buf[2].id = 0x00030003;
    sq_buf[2].opcode = 0x0001;
    sq_buf[2].flags = 0x0000;
    sq_buf[2].local_key = PAYLOAD_BUFFER_BASE + 768;
    sq_buf[2].remote_key = REMOTE_BUFFER_BASE + 0x2000; // Destination: 0x40002000
    sq_buf[2].length_lo = 512;
    sq_buf[2].length_hi = 0;
    for (int i = 0; i < 8; i++) sq_buf[2].reserved[i] = 0;
    print_sq_entry(2, &sq_buf[2]);

    // Test 4: Small transfer (128 bytes) - offset 0x3000
    sq_buf[3].id = 0x00040004;
    sq_buf[3].opcode = 0x0001;
    sq_buf[3].flags = 0x0000;
    sq_buf[3].local_key = PAYLOAD_BUFFER_BASE + 1280;
    sq_buf[3].remote_key = REMOTE_BUFFER_BASE + 0x3000; // Destination: 0x40003000
    sq_buf[3].length_lo = 128;
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

    for (uint32_t test_idx = 0; test_idx < 4; ++test_idx) {
        xil_printf("\n--- Test %u: Submitting SQ entry %u ---\n", test_idx + 1, test_idx);

        uint32_t sq_tail_before = Xil_In32(REG_ADDR(REG_IDX_SQ_TAIL));
        uint32_t sq_head_before = Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD));
        uint32_t cq_tail_before = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));

        xil_printf("Before: SQ_HEAD=%u, SQ_TAIL=%u, CQ_TAIL=%u\n",
                   sq_head_before, sq_tail_before, cq_tail_before);
        uint32_t new_tail;
        // Update tail to submit work
        if(test_idx ==0 || test_idx == 2){
            new_tail = sq_tail_before + 1;
        }else{
        new_tail = sq_tail_before + 1;
        }
        Xil_Out32(REG_ADDR(REG_IDX_SQ_TAIL), new_tail);
        xil_printf("Wrote SQ_TAIL=%u\n", new_tail);

        // Poll for SQ_HEAD advancement
        const uint32_t timeout = 1000000;
        uint32_t poll_count = 0;
        uint32_t sq_head_after = sq_head_before;

        while (poll_count < timeout) {
            sq_head_after = Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD));
            if (sq_head_after != sq_head_before) {
                break;
            }
            for (volatile int d = 0; d < 100; ++d) __asm__("nop");
            poll_count++;
        }

        if (sq_head_after != sq_head_before) {
            xil_printf("SUCCESS: SQ_HEAD advanced to %u after %u polls\n",
                       sq_head_after, poll_count);
        } else {
            xil_printf("TIMEOUT: SQ_HEAD stuck at %u after %u polls\n",
                       sq_head_after, poll_count);
        }

        // Wait a bit more for CQ write to complete
        for (volatile int d = 0; d < 10000; ++d) __asm__("nop");

        // Check CQ_TAIL advancement
        uint32_t cq_tail_after = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));
        xil_printf("After: SQ_HEAD=%u, SQ_TAIL=%u, CQ_TAIL=%u\n",
                   sq_head_after, new_tail, cq_tail_after);
        Xil_DCacheInvalidateRange((UINTPTR)&cq_buf, 4*sizeof(cq_entry_t));

        if (cq_tail_after != cq_tail_before) {
            xil_printf("CQ_TAIL advanced from %u to %u\n", cq_tail_before, cq_tail_after);

            // Invalidate cache and read CQ entry
            Xil_DCacheInvalidateRange((UINTPTR)&cq_buf[cq_tail_before], 4*sizeof(cq_entry_t));
            print_cq_entry(cq_tail_before, &cq_buf[cq_tail_before]);

            // Update CQ_HEAD to acknowledge completion
            Xil_Out32(REG_ADDR(REG_IDX_CQ_HEAD), cq_tail_after);
            xil_printf("Updated CQ_HEAD to %u\n", cq_tail_after);
            
            // Verify data was written to remote buffer
            uint32_t remote_offset = (sq_buf[test_idx].remote_key - REMOTE_BUFFER_BASE) / 4;
            uint32_t expected_offset = (sq_buf[test_idx].local_key - PAYLOAD_BUFFER_BASE) / 4;
            uint32_t verify_words = sq_buf[test_idx].length_lo / 4;
            
            xil_printf("\n--- Verifying Remote Write ---\n");
            xil_printf("Remote addr: 0x%08x (offset %u words)\n", 
                      (unsigned)sq_buf[test_idx].remote_key, remote_offset);
            xil_printf("Expected pattern from payload offset %u\n", expected_offset);
            
            // Invalidate cache for remote buffer region
            Xil_DCacheInvalidateRange((UINTPTR)&remote_buf[0], 1024*1024);
            
            uint32_t match_count = 0;
            uint32_t mismatch_count = 0;
            for (uint32_t i = 0; i < verify_words && i < 8; ++i) {
                uint32_t expected = payload_buf[expected_offset + i];
                uint32_t actual = remote_buf[remote_offset + i];
                if (actual == expected) {
                    match_count++;
                } else {
                    mismatch_count++;
                    xil_printf("  [%u] Expected: 0x%08x, Got: 0x%08x MISMATCH\n", 
                              i, expected, actual);
                }
            }
            
            if (mismatch_count == 0) {
                xil_printf("PASS: All %u sample words verified correctly\n", match_count);
            } else {
                xil_printf("FAIL: %u mismatches found\n", mismatch_count);
            }
        } else {
            xil_printf("WARNING: CQ_TAIL did not advance (still %u)\n", cq_tail_after);
        }

        xil_printf("\n");
    }

    // Final summary
    xil_printf("========================================\n");
    xil_printf("Test Summary\n");
    xil_printf("========================================\n");
    xil_printf("Final SQ_HEAD: %u\n", Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD)));
    xil_printf("Final SQ_TAIL: %u\n", Xil_In32(REG_ADDR(REG_IDX_SQ_TAIL)));
    xil_printf("Final CQ_HEAD: %u\n", Xil_In32(REG_ADDR(REG_IDX_CQ_HEAD)));
    xil_printf("Final CQ_TAIL: %u\n", Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL)));

    // Display all CQ entries written
    xil_printf("\n========================================\n");
    xil_printf("All CQ Entries Written\n");
    xil_printf("========================================\n");
    Xil_DCacheInvalidateRange((UINTPTR)cq_buf, 32 * 8);
    for (uint32_t i = 0; i < 3; ++i) {
        print_cq_entry(i, &cq_buf[i]);
    }

    // Final remote buffer dump
    xil_printf("\n========================================\n");
    xil_printf("Remote Buffer Sample Dump\n");
    xil_printf("========================================\n");
    Xil_DCacheInvalidateRange((UINTPTR)remote_buf, 16384);
    
    xil_printf("\nOffset 0x0000 (Test 1 - 256 bytes):\n");
    for (uint32_t i = 0; i < 4; ++i) {
        xil_printf("  [%04u] 0x%08x\n", i, remote_buf[i]);
    }
    
    xil_printf("\nOffset 0x1000 (Test 2 - 512 bytes):\n");
    for (uint32_t i = 0; i < 4; ++i) {
        xil_printf("  [%04u] 0x%08x\n", 0x400 + i, remote_buf[0x400 + i]);
    }
    
    xil_printf("\nOffset 0x2000 (Test 3 - 512 bytes):\n");
    for (uint32_t i = 0; i < 4; ++i) {
        xil_printf("  [%04u] 0x%08x\n", 0x800 + i, remote_buf[0x800 + i]);
    }
    
    xil_printf("\nOffset 0x3000 (Test 4 - 128 bytes):\n");
    for (uint32_t i = 0; i < 4; ++i) {
        xil_printf("  [%04u] 0x%08x\n", 0xC00 + i, remote_buf[0xC00 + i]);
    }

    xil_printf("\n========================================\n");
    xil_printf("RDMA Loopback TX->RX Test Complete\n");
    xil_printf("========================================\n\n");

    return 0;
}
