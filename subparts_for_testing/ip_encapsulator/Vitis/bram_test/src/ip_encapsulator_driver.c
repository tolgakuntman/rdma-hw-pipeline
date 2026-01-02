#include "ip_encapsulator_driver.h"
#include "xil_io.h"
#include <stdio.h>

#define BRAM_ENTRY_SIZE    32          // 256-bit entry = 32 bytes
#define WORDS_PER_ENTRY     8          // 8 x 32-bit words

typedef struct {
    uint32_t word[8];
} bram_entry_t;

/**
 * Compute BRAM index from destination IP address
 * Matches the hash function in endpoint_lookup.v:
 *   computed_index = dst_ip[ADDR_WIDTH-1:0] ^ dst_ip[ADDR_WIDTH+7:8]
 * For ADDR_WIDTH=8: dst_ip[7:0] ^ dst_ip[15:8]
 */
uint8_t compute_bram_index(uint32_t dst_ip) {
    return (dst_ip & 0xFF) ^ ((dst_ip >> 8) & 0xFF);
}

/**
 * Write endpoint entry to BRAM
 * 
 * @param bram_base Base address of AXI BRAM Controller
 * @param dst_ip Destination IP address (32-bit, network byte order)
 * @param dst_mac Destination MAC address (48-bit)
 * @param src_mac Source MAC address (48-bit)
 * 
 * BRAM entry format (192 bits = 24 bytes, MSB-first):
 *   [191]: entry_valid (1 = valid)
 *   [190:160]: reserved (31 bits)
 *   [159:128]: dst_ip (32 bits)
 *   [127:80]: dst_mac (48 bits)
 *   [79:32]: src_mac (48 bits)
 *   [31:0]: reserved
 */
void write_endpoint_entry(uint32_t bram_base, uint32_t dst_ip, 
                          uint64_t dst_mac, uint64_t src_mac) {
    uint8_t index = compute_bram_index(dst_ip);
    uint32_t addr = bram_base + (index * 32); // 32 bytes per entry

    //new logic
    bram_entry_t e;
    memset(e.word, 0, sizeof(e.word));

    e.word[7] = 0x80000000;                     // valid bit

    e.word[6] = dst_ip;                         

    e.word[5] = (uint32_t)(dst_mac >> 16);     
    e.word[4] = (uint32_t)((dst_mac & 0xFFFF) << 16) | 
                  (uint32_t)((src_mac >> 32) & 0xFFFF); 

    e.word[3] = (uint32_t)src_mac;    
    

    for (int i = 0; i < WORDS_PER_ENTRY; i++)
    {
        Xil_Out32(addr + (i * 4), e.word[i]);
    }
    
    printf("Wrote endpoint entry: IP=0x%08X, DST_MAC=0x%012llX, SRC_MAC=0x%012llX, Index=%d\n",
           dst_ip, dst_mac, src_mac, index);
}

/**
 * Read endpoint entry from BRAM (for verification)
 */
void read_endpoint_entry(uint32_t bram_base, uint8_t index) {
    uint32_t addr = bram_base + (index * 32);

    //new logic
    bram_entry_t e;

    for (int i = 0; i < WORDS_PER_ENTRY; i++)
    {
        e.word[i] = Xil_In32(addr + (i * 4));
        xil_printf("Addr %08x W[%d] = %08x\n", addr + i*4, i, e.word[i]);
    }

    // 1. Get Valid bit
    uint8_t valid = (e.word[7] >> 31) & 0x1;
    
    // 2. Get DST IP
    uint32_t read_dst_ip = e.word[6];
    
    // 3. Get DST MAC
    uint64_t read_dst_mac = ((uint64_t)e.word[5] << 16) | // W5: MAC[47:16] -> [63:16]
                            ((e.word[4] >> 16) & 0xFFFF); // W4: MAC[15:0] -> [15:0]
    
    // 4. Get SRC MAC
    uint64_t read_src_mac = ((uint64_t)(e.word[4] & 0xFFFF) << 32) | // W4: MAC[47:32] -> [47:32]
                            e.word[3]; // W3: MAC[31:0] -> [31:0]
    
    printf("--- Parsed Values ---\n");
    printf(" Valid: %u\n", valid);
    printf(" IP: 0x%08X\n", read_dst_ip);
    printf(" DST_MAC: 0x%012llX\n", read_dst_mac);
    printf(" SRC_MAC: 0x%012llX\n", read_src_mac);

}


/**
 * Enable IP Encapsulator
 */
void enable_ip_encapsulator(uint32_t ip_base) {
    uint32_t ctrl = Xil_In32(ip_base + IP_ENCAP_REG_CONTROL);
    Xil_Out32(ip_base + IP_ENCAP_REG_CONTROL, ctrl | IP_ENCAP_CTRL_ENABLE);
    printf("IP Encapsulator enabled (CONTROL=0x%08X)\n", 
           Xil_In32(ip_base + IP_ENCAP_REG_CONTROL));
}


/**
 * Disable IP Encapsulator
 */
void disable_ip_encapsulator(uint32_t ip_base) {
    uint32_t ctrl = Xil_In32(ip_base + IP_ENCAP_REG_CONTROL);
    Xil_Out32(ip_base + IP_ENCAP_REG_CONTROL, ctrl & ~IP_ENCAP_CTRL_ENABLE);
    printf("IP Encapsulator disabled\n");
}


/**
 * Clear packet and byte counters
 */
void clear_counters(uint32_t ip_base) {
    // Read current control value
    uint32_t ctrl = Xil_In32(ip_base + IP_ENCAP_REG_CONTROL);
    
    // Pulse bit 2 to clear counters
    Xil_Out32(ip_base + IP_ENCAP_REG_CONTROL, ctrl | IP_ENCAP_CTRL_CLEAR_COUNTERS);
    
    // Clear the bit (pulse completed)
    Xil_Out32(ip_base + IP_ENCAP_REG_CONTROL, ctrl & ~IP_ENCAP_CTRL_CLEAR_COUNTERS);
    
    printf("Counters cleared\n");
}

/**
 * Read status register
 */
uint32_t read_status(uint32_t ip_base) {
    return Xil_In32(ip_base + IP_ENCAP_REG_STATUS);
}

/**
 * Read packet count (64-bit)
 */
uint64_t read_packet_count(uint32_t ip_base) {
    uint32_t lo = Xil_In32(ip_base + IP_ENCAP_REG_PKT_COUNT_LO);
    uint32_t hi = Xil_In32(ip_base + IP_ENCAP_REG_PKT_COUNT_HI);
    return ((uint64_t)hi << 32) | lo;
}

/**
 * Read byte count (64-bit)
 */
uint64_t read_byte_count(uint32_t ip_base) {
    uint32_t lo = Xil_In32(ip_base + IP_ENCAP_REG_BYTE_COUNT_LO);
    uint32_t hi = Xil_In32(ip_base + IP_ENCAP_REG_BYTE_COUNT_HI);
    return ((uint64_t)hi << 32) | lo;
}


/**
 * Print status information
 */
void print_status(uint32_t ip_base) {
    uint32_t status = read_status(ip_base);
    uint32_t control = Xil_In32(ip_base + IP_ENCAP_REG_CONTROL);
    uint64_t pkt_count = read_packet_count(ip_base);
    uint64_t byte_count = read_byte_count(ip_base);
    
    printf("=== IP Encapsulator Status ===\n");
    printf("Control:  0x%08X\n", control);
    printf("  Enable:         %s\n", (control & IP_ENCAP_CTRL_ENABLE) ? "Yes" : "No");
    printf("  Loopback:       %s\n", (control & IP_ENCAP_CTRL_LOOPBACK) ? "Yes" : "No");
    printf("  IRQ Enable:     %s\n", (control & IP_ENCAP_CTRL_IRQ_ENABLE) ? "Yes" : "No");
    printf("Status:   0x%08X\n", status);
    printf("  Ready:          %s\n", (status & IP_ENCAP_STATUS_READY) ? "Yes" : "No");
    printf("  Lookup Error:   %s\n", (status & IP_ENCAP_STATUS_LOOKUP_ERROR) ? "Yes" : "No");
    printf("  IRQ Pending:    %s\n", (status & IP_ENCAP_STATUS_IRQ_PENDING) ? "Yes" : "No");
    printf("Packet Count:  %llu\n", pkt_count);
    printf("Byte Count:    %llu\n", byte_count);
    printf("==============================\n");
}

