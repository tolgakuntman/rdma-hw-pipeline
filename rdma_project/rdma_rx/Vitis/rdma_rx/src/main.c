#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "sleep.h"

#include "xaxiethernet.h"
#include "xaxiethernet_hw.h"
#include <stdint.h>
#include <xil_types.h>

/* -------------------------------------------------------------------------
 * Donanım ID’leri
 * ------------------------------------------------------------------------- */
#define ETH_DEV_ID          0

/* KR260 kartında çalışan PHY adresi */
#define PHY_ADDR_CONFIG     2

/* MAC adresi (TX pattern generator ile de aynısı) */
static u8 BoardMac[6] = {0x00, 0x0A, 0x35, 0x01, 0x02, 0x03};

/* PHY register adresleri */
#define PHY_REG_BMCR   0
#define PHY_REG_BMSR   1

/* BMCR bitleri */
#define BMCR_AUTONEG_EN  0x1000
#define BMCR_RESTART_AN  0x0200

/* BMSR bitleri */
#define BMSR_LINK_STATUS  0x0004

/* -------------------------------------------------------------------------
 * RDMA yazılarının gittiği DDR buffer
 * ------------------------------------------------------------------------- */
#define REMOTE_BUFFER_BASE 0x20000000U
#define REMOTE_BUFFER_SIZE_BYTES  (64 * 1024)   // örnek: 64 KB’lik bölge

volatile uint32_t *remote_buff = (volatile uint32_t *) REMOTE_BUFFER_BASE;

static XAxiEthernet EthInst;


/* ------------------------------------------------------------------------- */
/* DDR snapshot helper (REMOTE_BUFFER_BASE’ten itibaren ilk N word) */
static void DumpRemoteBuf(int max_words)
{
    int i;
    uint32_t addr;
    uint32_t w;
    xil_printf("---- DDR DUMP @ 0x%08lx (first %d words) ----\r\n",
               (unsigned long)REMOTE_BUFFER_BASE, max_words);

    for (i = 0; i < max_words; i++) {
        addr = REMOTE_BUFFER_BASE + 4 * i;
        w    = remote_buff[i];   // DCache kapalı → her zaman taze okuma

        xil_printf("%03d: [0x%08lx] = 0x%08lx\r\n",
                   i,
                   (unsigned long)addr,
                   (unsigned long)w);
    }

    xil_printf("---- END DDR DUMP ----\r\n");
}

/* ------------------------------------------------------------------------- */
static int InitEth(int *FoundPhyAddr)
{
    int Status;
    XAxiEthernet_Config *EthCfg;
    u32 Options;
    int PhyAddr = -1;

    xil_printf("\r\n=== InitEth() basladi ===\r\n");

    xil_printf("ETH-1: XAxiEthernet_LookupConfig (ID=%d)\r\n", ETH_DEV_ID);
    EthCfg = XAxiEthernet_LookupConfig(ETH_DEV_ID);
    if (!EthCfg) {
        xil_printf("  [ERR] LookupConfig FAIL\r\n");
        return XST_FAILURE;
    }
    xil_printf("  BaseAddress = 0x%08lx\r\n",
               (unsigned long)EthCfg->BaseAddress);

    xil_printf("ETH-2: CfgInitialize\r\n");
    Status = XAxiEthernet_CfgInitialize(&EthInst, EthCfg,
                                        EthCfg->BaseAddress);
    if (Status != XST_SUCCESS) {
        xil_printf("  [ERR] CfgInitialize FAIL (%d)\r\n", Status);
        return Status;
    }

    xil_printf("ETH-2.5: SetOperatingSpeed 1000 Mbps\r\n");
    Status = XAxiEthernet_SetOperatingSpeed(&EthInst, XAE_SPEED_1000_MBPS);
    if (Status != XST_SUCCESS)
        xil_printf("  [WARN] SetOperatingSpeed FAIL (%d)\r\n", Status);

    xil_printf("ETH-3: SetMacAddress\r\n");
    Status = XAxiEthernet_SetMacAddress(&EthInst, BoardMac);
    if (Status != XST_SUCCESS) {
        xil_printf("  [ERR] SetMacAddress FAIL (%d)\r\n", Status);
        return Status;
    }

    xil_printf("ETH-4: Options ayarla\r\n");
    Options = XAxiEthernet_GetOptions(&EthInst);
    xil_printf("  Default Options = 0x%08lx\r\n", (unsigned long)Options);

    /* RX ve TX’i aç, FCS strip + flow control kullan */
    Options |=  XAE_FLOW_CONTROL_OPTION
             |  XAE_TRANSMITTER_ENABLE_OPTION
             |  XAE_RECEIVER_ENABLE_OPTION
             |  XAE_FCS_STRIP_OPTION;

    XAxiEthernet_SetOptions(&EthInst, Options);
    XAxiEthernet_ClearOptions(&EthInst, ~Options);

    xil_printf("  Yeni Options = 0x%08lx\r\n", (unsigned long)Options);

    /* PHY INIT */
    xil_printf("ETH-5: PHY init\r\n");

    PhyAddr = PHY_ADDR_CONFIG;

    {
        u16 Bmsr;
        XAxiEthernet_PhyRead(&EthInst, PhyAddr, PHY_REG_BMSR, &Bmsr);
        xil_printf("  PHY addr %d: BMSR = 0x%04x\r\n",
                   PhyAddr, (unsigned)Bmsr);
    }

    xil_printf("ETH-6: PHY autoneg enable/restart\r\n");
    {
        u16 Bmcr;
        XAxiEthernet_PhyRead(&EthInst, PhyAddr, PHY_REG_BMCR, &Bmcr);
        xil_printf("  BMCR eski = 0x%04x\r\n", Bmcr);
        Bmcr |= BMCR_AUTONEG_EN | BMCR_RESTART_AN;
        XAxiEthernet_PhyWrite(&EthInst, PhyAddr, PHY_REG_BMCR, Bmcr);
        xil_printf("  BMCR yeni yazildi = 0x%04x\r\n", Bmcr);
    }

    xil_printf("ETH-7: XAxiEthernet_Start\r\n");
    XAxiEthernet_Start(&EthInst);

    xil_printf("ETH-8: LINK bekleniyor...\r\n");
    {
        int i;
        u16 Bmsr = 0;
        for (i = 0; i < 100; i++) {
            XAxiEthernet_PhyRead(&EthInst, PhyAddr, PHY_REG_BMSR, &Bmsr);
            XAxiEthernet_PhyRead(&EthInst, PhyAddr, PHY_REG_BMSR, &Bmsr);
            if (Bmsr & BMSR_LINK_STATUS) {
                xil_printf("  LINK UP, BMSR = 0x%04x\r\n", Bmsr);
                break;
            }
            usleep(100000);
        }
        if (!(Bmsr & BMSR_LINK_STATUS))
            xil_printf("  [WARN] Link DOWN, son BMSR = 0x%04x\r\n", Bmsr);
    }

    *FoundPhyAddr = PhyAddr;
    xil_printf("=== InitEth() OK ===\r\n");
    return XST_SUCCESS;
}

/* ------------------------------------------------------------------------- */
int main(void)
{
    int Status;
    int PhyAddr;

    /* Cache ayarları: D-cache kapalı (DMA ile coherency derdi olmasın) */
    Xil_DCacheDisable();
    Xil_ICacheEnable();

    for (uint32_t i = 0; i < 4096; i++) {
        remote_buff[i] = 0x00000000U;
    }
    Xil_DCacheFlushRange((UINTPTR)remote_buff, 16384);

    xil_printf("\r\n========================================\r\n");
    xil_printf("==  PL Ethernet RX -> RDMA + DDR DUMP ==\r\n");
    xil_printf("========================================\r\n");

    xil_printf("STEP 1: InitEth()\r\n");
    Status = InitEth(&PhyAddr);
    if (Status != XST_SUCCESS) {
        xil_printf("[FATAL] InitEth FAIL (%d)\r\n", Status);
        return XST_FAILURE;
    }

    xil_printf("MAIN: PHY addr = %d\r\n", PhyAddr);
    xil_printf("MAIN: PC'den Scapy ile tek bir burst RDMA paketi gonder.\r\n");
    xil_printf("      Ilk byte ile son byte arasindaki net hizi olcecegiz.\r\n");

    xil_printf("\r\nMAIN: Olcum bitti, kart idle modda. Yeni deney icin resetle.\r\n");

    while (1) {
        sleep(1);  // sonsuza kadar takilsin
        DumpRemoteBuf(1);
    }

    return 0;
}
