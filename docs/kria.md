# First reading

The **Kria KR260 (KV260/KD240)** is part of the **Zynq UltraScale+ family**. (The Pynq Board is part of the Zynq family). Zynq UltraScale+ is bigger than Zynq and has extra features like **BL31 ARM Trusted Firmware** which allows execution of a secure payload.

On the [SOM landing page](https://xilinx.github.io/kria-apps-docs/home/build/html/index.html) you find an overview of the most important information.

The [**bitstream management**](https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/docs/bitstream_management.html) on the Kria uses a different approach compared to Zynq on the Pynq Boards. 
A separate bitstream can be created and **loaded without the need to reboot/rebuild the sd card**.

Before you start building the embedded system, read these links.

#### Important Github pages

- [https://github.com/Xilinx/kria-vitis-platforms](https://github.com/Xilinx/kria-vitis-platforms)
- [https://github.com/Xilinx/kria-apps-firmware](https://github.com/Xilinx/kria-apps-firmware)

#### Building your own overlay

- [https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/index.html](https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/index.html)

#### Tools used on Linux with Kria

- [https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/docs/target.html](https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/docs/target.html)

### Important files

I will provide you with these files.

WKS01BSP in virtualbox :
```
/data/vakken/2425/S1/RND/HO/xilinx-kr260-startkit-2024.1-vitis (platform, vadd)
/data/vakken/2425/S1/RND/HO/xilinx-kr260-startkit-2024.1 (xsa, vivado project)
```
sd card files:
```
/data/kria/iot-limerick-kria-classic-desktop-2204-20240304-165.img.xz (ubuntu 22.04, graphical, that can load vadd)
/data/kria/K26-BootFW-01.02-06140626.bin (to update firmware)
/data/vakken/2425/S1/RND/HO/WK01/wk01_1.wic (console, petalinux build, can load vadd)
```

## Updating the Kria Firmware

The first thing you should do is make sure the Kria KR260 has the latest firmware image. This part describes how to update the firmware.

Download initial sd image from [here](https://ubuntu.com/download/amd).

This is the firmware image you need:

- [https://account.amd.com/en/forms/downloads/xef.html?filename=K26-BootFW-01.02-06140626.bin](https://account.amd.com/en/forms/downloads/xef.html?filename=K26-BootFW-01.02-06140626.bin)

Steps needed to update the firmware:

- Write initial sd image to sd card: /data/kria/iot-limerick-kria-classic-desktop-2204-20240304-165.img.xz
- Boot from inital SD Card 
- Connect networkcable/insert SD Card/insert power cable
- check your ip: 
  ```
  ifconfig
  ```
- Copy the firmware image from your laptop to the Kria:
  ```
  scp yuri@10.42.0.1:/data/kria/K26-BootFW-01.02-06140626.bin .
  sudo xmutil bootfw_update -i K26-BootFW-01.02-06140626.bin
  sudo reboot
  sudo xmutil bootfw_update -v
  ```

Read more about the [Boot-FW-Update Process](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/1641152513/Kria+SOMs+Starter+Kits#Boot-FW-Update-Process).

### FW Update procedure:

Boot FW update with xmutil command line tool.  
The xmutil provides a utility to help in the update of the on-target boot firmware with the following steps:

- Download the boot firmware update from the site above. It should be a Xilinx BOOT.BIN file.

- Move the BOOT.BIN file to the SOM Starter Kit target using FTP (or similar method). Note when copying file remotely you must copy it to the petalinux user directory.

- Execute the A/B update process through these steps

- Execute “sudo xmutil bootfw_update -i <path to boot.bin>”.

- The tool returns the image (A or B) that is updated, and is marked for boot on the next boot.

- You can verify the updated status of the boot firmware using the sudo xmutil bootfw_status utility.

After the BOOT.BIN image write is completed the SoC device needs to be reset (POR_B). This can be accomplished by pressing the RESET push-button on the carrier card, power cycling the board, or with 2023.2 or later version of the Linux bootfw_update utility a Linux “sudo reboot” will handle the reset. 

After restart it is required by the user verify that Linux fully boots with the new boot FW to verify functionality. This is completed by executing 

```
sudo xmutil bootfw_update -v
```

 to validate successful boot against the new firmware. Note this must be completed on the platform restart immediately following the update, else the platform will fall back to the other boot partition on the next restart.

## Constraints (pinout)

You will want to know how to figure out which pins are connected to the board to be able to create your constraints file. The schematics will help you.

- [Kria KR260 Schematics](https://adaptivesupport.amd.com/s/question/0D54U00006alUwcSAE/kria-som-kr260-starter-kit-schematic-pdf-vs-constrains-xdc-pin-confusion-possible-explanation-on-fan-pinout?language=en_US)
- [How to find pinouts](https://adaptivesupport.amd.com/s/question/0D54U00006alUwcSAE/kria-som-kr260-starter-kit-schematic-pdf-vs-constrains-xdc-pin-confusion-possible-explanation-on-fan-pinout?language=en_US)
- [Tom Verbeure, pinout lookup](https://github.com/tomverbeure/kv260_bringup)

## Useful links (some more reading to start thinking about your final project)

- [Using Pmod with a custom design](https://www.hackster.io/whitney-knitter/rpi-pmod-connector-gpio-with-custom-pl-design-in-kria-kr260-53c40e)
- [Replacing the KR260 BSP bitstream with your own custom bitstream](https://adaptivesupport.amd.com/s/question/0D54U00007oSsApSAK/info-post-replacing-the-kr260-bsp-bitstream-with-your-own-custom-bitstream-20231?language=en_US)
- [Digilent PMOD LED arrays](https://digilent.com/shop/pmod-8ld-eight-high-brightness-leds/) (could be useful for debugging)
  
## First tryouts

As first steps to start working with the KR260, I found Whitney Knitter her articles on Hackster.io very useful.  
She uses an older version in her tutorial, but you can start from the [2024.1 bsp](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/1641152513/Kria+SOMs+Starter+Kits#PetaLinux-Board-Support-Packages)  
When you start configuring petalinux, do not forget to enable the fpgamanager and bootargs:
```
    earlycon clk_ignore_unused earlyprintk root=/dev/sda2 rw rootwait cma=1024M
```

5 very good tutorials which start from scratch:

- [https://www.hackster.io/whitney-knitter/getting-started-with-the-kria-kr260-in-vivado-2022-1-33746d](https://www.hackster.io/whitney-knitter/getting-started-with-the-kria-kr260-in-vivado-2022-1-33746d)
- [https://www.hackster.io/whitney-knitter/add-peripheral-support-to-kria-kr260-vivado-2022-1-project-874960](https://www.hackster.io/whitney-knitter/add-peripheral-support-to-kria-kr260-vivado-2022-1-project-874960)
- [https://www.hackster.io/whitney-knitter/accelerated-design-development-on-kria-kr260-in-vitis-2022-1-883799](https://www.hackster.io/whitney-knitter/accelerated-design-development-on-kria-kr260-in-vitis-2022-1-883799)
- [https://www.hackster.io/whitney-knitter/getting-started-with-the-kria-kr260-in-petalinux-2022-1-daec16](https://www.hackster.io/whitney-knitter/getting-started-with-the-kria-kr260-in-petalinux-2022-1-daec16)
- [https://www.hackster.io/whitney-knitter/rpi-pmod-connector-gpio-with-custom-pl-design-in-kria-kr260-53c40e](https://www.hackster.io/whitney-knitter/rpi-pmod-connector-gpio-with-custom-pl-design-in-kria-kr260-53c40e)

If you get an error concerning tftpboot: 

- [https://adaptivesupport.amd.com/s/question/0D54U00008dL4MESA0/error-module-plnxvars-has-no-attribute-copydir?language=en_US](https://adaptivesupport.amd.com/s/question/0D54U00008dL4MESA0/error-module-plnxvars-has-no-attribute-copydir?language=en_US)

### Device Tree Compiler

The device tree gives you information about your system, this helps to check if the hardware design you created is usable in your embedded linux system. When your system is running you can look into the /sys/firmwware/devicetree folder to examine the devicetree.

```
ls /sys/firmware/devicetree/
```

If you would like to get the whole the devicetree into one file to have a better overview, you can use the tool 'dtc' to create a file system.dts: 

```
dtc -I fs -O dts -o system.dts /proc/device-tree
```

### Vitis Platform Creation Tutorial

This [tutorial](https://github.com/Xilinx/Vitis-Tutorials/blob/2024.1/Vitis_Platform_Creation/Design_Tutorials/01-Edge-KV260/step1.md) has some useful information about creating/changing your hardware design.

Error concerning hashstyle in vitis: 

- [https://adaptivesupport.amd.com/s/question/0D54U00008M8chgSAB/202321-pmufw-cant-be-built-unrecognized-option-hashstylegnu?language=en_US](https://adaptivesupport.amd.com/s/question/0D54U00008M8chgSAB/202321-pmufw-cant-be-built-unrecognized-option-hashstylegnu?language=en_US)

### Kria SOM Adventure Map

This [map](https://xilinx.github.io/kria-apps-docs/Kria_doc_map/map.htm) gives a nice overview of which pages to read and tutorials to follow to better understand the workflow with the Kria.

### Booting the first time

Read about setting up the [SD card image](https://www.amd.com/en/products/system-on-modules/kria/k26/kr260-robotics-starter-kit/getting-started/setting-up-the-sd-card-image.html).

Download the Ubuntu 22.04 image for Kria from:
[https://ubuntu.com/download/amd#kria-kv260-kr260](https://ubuntu.com/download/amd#kria-kv260-kr260)

Write it to an sd card using [Balena Etcher](https://etcher.balena.io/)

``` bash
sudo apt update
sudo apt upgrade
sudo apt install qt
```

### Interesting links

- [https://community.element14.com/technologies/fpga-group/b/blog/posts/kv260-vvas-sms-2021-1-part1](https://community.element14.com/technologies/fpga-group/b/blog/posts/kv260-vvas-sms-2021-1-part1)
- [https://discuss.pynq.io/t/kria-pynq-v3-0-release-now-with-kr260-support/4865](https://discuss.pynq.io/t/kria-pynq-v3-0-release-now-with-kr260-support/4865)
- [https://github.com/Xilinx/kria-base-hardware/tree/2023.1/k26_starter_kits](https://github.com/Xilinx/kria-base-hardware/tree/2023.1/k26_starter_kits)
- [https://community.element14.com/technologies/fpga-group/b/blog/posts/kv260-vvas-sms-2021-1-blog](https://community.element14.com/technologies/fpga-group/b/blog/posts/kv260-vvas-sms-2021-1-blog)
- [https://adaptivesupport.amd.com/s/question/0D54U00007oSsApSAK/info-post-replacing-the-kr260-bsp-bitstream-with-your-own-custom-bitstream-20231?language=en_US](https://adaptivesupport.amd.com/s/question/0D54U00007oSsApSAK/info-post-replacing-the-kr260-bsp-bitstream-with-your-own-custom-bitstream-20231?language=en_US)
- [BSP 2024.1](https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-kr260-starterkit-v2024.1-05230256.bsp)
- [BIST KD240](https://www.hackster.io/LogicTronix/kria-kd240-petalinux-2023-1-bist-tutorial-fa01de)
- [BIST KR260](https://xilinx.github.io/kria-apps-docs/kr260/build/html/docs/bist/docs/setup_kr260.html)

### AXI DMA

- [https://pp4fpgas.readthedocs.io/en/latest/axidma2.html](https://pp4fpgas.readthedocs.io/en/latest/axidma2.html)
- [DMA on KR260](https://www.hackster.io/yuricauwerts/slaying-the-dma-dragon-on-the-kria-kr260-a5046e)
- [MCDMA on KR260](https://www.hackster.io/yuricauwerts/using-mcdma-from-linux-on-kria-kr260-45ab74)

## What next?

- Get SD card up and running
- ...