#ifndef IP_ENCAPSULATOR_DRIVER_H
#define IP_ENCAPSULATOR_DRIVER_H

#include <stdint.h>

// AXI-Lite Register Map (from axi_lite_regs.v)
#define IP_ENCAP_REG_CONTROL      0x00
#define IP_ENCAP_REG_STATUS       0x04
#define IP_ENCAP_REG_PKT_COUNT_LO 0x10
#define IP_ENCAP_REG_PKT_COUNT_HI 0x14
#define IP_ENCAP_REG_BYTE_COUNT_LO 0x18
#define IP_ENCAP_REG_BYTE_COUNT_HI 0x1C
#define IP_ENCAP_REG_BRAM_BASE    0x20
#define IP_ENCAP_REG_BRAM_SIZE    0x24
#define IP_ENCAP_REG_SQ_HEAD      0x30
#define IP_ENCAP_REG_SQ_TAIL      0x34
#define IP_ENCAP_REG_CQ_HEAD      0x38
#define IP_ENCAP_REG_CQ_TAIL      0x3C
#define IP_ENCAP_REG_IRQ_ACK      0x40

// Control register bits
#define IP_ENCAP_CTRL_ENABLE          (1 << 0)
#define IP_ENCAP_CTRL_LOOPBACK        (1 << 1)
#define IP_ENCAP_CTRL_CLEAR_COUNTERS  (1 << 2)
#define IP_ENCAP_CTRL_IRQ_ENABLE      (1 << 3)

// Status register bits
#define IP_ENCAP_STATUS_READY         (1 << 0)
#define IP_ENCAP_STATUS_LOOKUP_ERROR  (1 << 1)
#define IP_ENCAP_STATUS_IRQ_PENDING   (1 << 2)

// BRAM entry format (192 bits = 24 bytes)
// Bit [191]: entry_valid
// Bits [159:128]: dst_ip (32 bits)
// Bits [127:80]: dst_mac (48 bits)
// Bits [79:32]: src_mac (48 bits)

// Function prototypes
uint8_t compute_bram_index(uint32_t dst_ip);
void write_endpoint_entry(uint32_t bram_base, uint32_t dst_ip, 
                          uint64_t dst_mac, uint64_t src_mac);
void read_endpoint_entry(uint32_t bram_base, uint8_t index);
void enable_ip_encapsulator(uint32_t ip_base);
void disable_ip_encapsulator(uint32_t ip_base);
void clear_counters(uint32_t ip_base);
uint32_t read_status(uint32_t ip_base);
uint64_t read_packet_count(uint32_t ip_base);
uint64_t read_byte_count(uint32_t ip_base);
void print_status(uint32_t ip_base);

#endif

