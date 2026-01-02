#include <stdio.h>
#include "xil_io.h"
#include "xparameters.h"
#include "ip_encapsulator_driver.h"

#define BRAM_BASE_ADDR     XPAR_AXI_BRAM_CTRL_0_BASEADDR  // AXI BRAM Controller base address
#define IP_ENCAP_BASE_ADDR XPAR_IP_ENCAPSULATOR_0_BASEADDR // IP Encapsulator AXI-Lite base address

// Example endpoint configuration
// Format: IP address in network byte order (big-endian)
#define SRC_IP  0x0A000001  // 10.0.0.1
#define DST_IP  0x0A000002  // 10.0.0.2

// MAC addresses (48-bit, big-endian)
#define SRC_MAC 0x00AABBCCDDEEULL
#define DST_MAC 0x001122334455ULL

// Test data
#define TEST_IP_1   0xC0A80164  // 192.168.1.100
#define TEST_MAC_1  0xAABBCCDDEE01ULL
#define SRC_MAC_1   0x112233445501ULL

#define TEST_IP_2   0xC0A80165  // 192.168.1.101
#define TEST_MAC_2  0xAABBCCDDEE02ULL
#define SRC_MAC_2   0x112233445502ULL

int main() {

    
    printf("=== IP Encapsulator Hardware Test ===\n\n");

    // Print base addresses
    printf("Base Addresses:\r\n");
    printf("  BRAM:      0x%08X\r\n", BRAM_BASE_ADDR);
    printf("  IP Encap:  0x%08X\r\n", IP_ENCAP_BASE_ADDR);
    printf("\r\n");


    // ========================================================================
    // Test 1: BRAM Access Test
    // ========================================================================
    printf("--- Test 1: BRAM Access ---\r\n");
    
    // Write test pattern
    printf("Writing test pattern to BRAM[0]...\r\n");
    Xil_Out32(BRAM_BASE_ADDR, 0xDEADBEEF);
    
    // Read back
    uint32_t test_read = Xil_In32(BRAM_BASE_ADDR);
    if (test_read == 0xDEADBEEF) {
        printf("  ✓ BRAM accessible (read: 0x%08X)\r\n\r\n", test_read);
    } else {
        printf("  ✗ BRAM read FAILED! (expected 0xDEADBEEF, got 0x%08X)\r\n", test_read);
        printf("  Check BRAM base address in Address Editor!\r\n\r\n");
        return -1;
    }
    
    // ========================================================================
    // Test 2: AXI-Lite Register Access Test
    // ========================================================================
    printf("--- Test 2: AXI-Lite Register Access ---\r\n");
    
    printf("Reading STATUS register...\r\n");
    uint32_t status = Xil_In32(IP_ENCAP_BASE_ADDR + IP_ENCAP_REG_STATUS);
    printf("  STATUS:  0x%08X\r\n", status);
    
    printf("Reading CONTROL register...\r\n");
    uint32_t control = Xil_In32(IP_ENCAP_BASE_ADDR + IP_ENCAP_REG_CONTROL);
    printf("  CONTROL: 0x%08X\r\n\r\n", control);
    
    if (status == 0xFFFFFFFF || control == 0xFFFFFFFF) {
        printf("  ⚠️  WARNING: Register reads returned 0xFFFFFFFF\r\n");
        printf("  This usually means:\r\n");
        printf("    - Wrong base address\r\n");
        printf("    - IP not connected in block design\r\n");
        printf("    - Clock/reset issue\r\n\r\n");
    }


    // ========================================================================
    // Test 3: Write Endpoint Entries
    // ========================================================================
    printf("--- Test 3: Write Endpoint Entries ---\r\n");
    
    printf("\r\nWriting entry 1...\r\n");
    write_endpoint_entry(BRAM_BASE_ADDR, TEST_IP_1, TEST_MAC_1, SRC_MAC_1);
    
    printf("\r\nWriting entry 2...\r\n");
    write_endpoint_entry(BRAM_BASE_ADDR, TEST_IP_2, TEST_MAC_2, SRC_MAC_2);
    
    printf("\r\n");
    
    // ========================================================================
    // Test 4: Read Back and Verify
    // ========================================================================
    printf("--- Test 4: Read Back and Verify ---\r\n");
    
    uint8_t index1 = compute_bram_index(TEST_IP_1);
    uint8_t index2 = compute_bram_index(TEST_IP_2);
    
    printf("\r\n");
    read_endpoint_entry(BRAM_BASE_ADDR, index1);
    
    printf("\r\n");
    read_endpoint_entry(BRAM_BASE_ADDR, index2);
    
    printf("\r\n");
    
    // ========================================================================
    // Test 5: Configure IP Encapsulator
    // ========================================================================
    printf("--- Test 5: Configure IP Encapsulator ---\r\n");
    
    printf("\r\nClearing counters...\r\n");
    clear_counters(IP_ENCAP_BASE_ADDR);
    
    printf("\r\nEnabling IP Encapsulator...\r\n");
    enable_ip_encapsulator(IP_ENCAP_BASE_ADDR);
    
    printf("\r\n");
    print_status(IP_ENCAP_BASE_ADDR);
    
    // ========================================================================
    // Test 6: Monitor Status
    // ========================================================================
    printf("\r\n--- Test 6: Monitoring Status ---\r\n");
    printf("Press Ctrl+C to stop...\r\n\r\n");
    
    int iteration = 0;
    uint64_t last_pkt_count = 0;
    
    while (1) {
        // Delay
        for (volatile int i = 0; i < 50000000; i++);
        
        // Read current packet count
        uint64_t curr_pkt_count = read_packet_count(IP_ENCAP_BASE_ADDR);
        
        // Print status every 10 iterations or if packets changed
        if (iteration % 10 == 0 || curr_pkt_count != last_pkt_count) {
            printf("\r\n[Iteration %d]\r\n", iteration);
            print_status(IP_ENCAP_BASE_ADDR);
            
            if (curr_pkt_count != last_pkt_count) {
                printf("  ⚠️  Packet count changed! (%llu -> %llu)\r\n",
                       last_pkt_count, curr_pkt_count);
            }
        } else {
            printf(".");  // Progress indicator
        }
        
        last_pkt_count = curr_pkt_count;
        iteration++;
    }
    
    return 0;
}

