# Overview

## 1. Camera capture and networking 

#### Objective

To capture video input from MIPI and HDMI sources, apply real-time image processing, and stream the output via Ethernet. 

#### Methodology 

##### Phase 1: HDMI baseline 

Set up a Raspberry Pi with a camera module providing an HDMI output. 

Use a PYNQ board, such as the KV260/PYNQZ2/AUP-ZU3, as the receiver. The board will be programmed to capture the HDMI stream via its programmable logic (PL). 

(Develop a Python application on the PYNQ framework to configure the PL for video capture and output the stream via Ethernet.) 

##### Phase 2: MIPI integration 

Transition from the Raspberry Pi setup to a native MIPI camera connected to a board with a MIPI interface, such as the KV260/AUP-ZU3/ZYBO. 

Implement a MIPI CSI-2 receiver in the PL to capture the raw sensor data. 

Pathway for MIPI to Ethernet on AUP-ZU3: MIPI cam à PL à DMA à PS à USB à Ethernet 

##### Phase 3: Real-time image processing 

Create a library of image filters (e.g., edge detection, color correction, noise reduction) that can be executed in the PL for high throughput. 

Develop a configuration UI (using a framework like PYNQ's web-based server) to allow a user to select and tune image filter parameters on the fly.  

**Hardware**: AUP-ZU3 / PYNQZ2, ZYBO / KV260 

#### Testing setup 

What to test: Video capture success, stream stability, image filter functionality, parameter update responsiveness, and Ethernet throughput. 

#### How to test 

Use a test pattern generator and a known image to verify filter accuracy. 

Measure the round-trip latency from camera capture to Ethernet output. 

Validate the Ethernet stream integrity using network analysis tools. 

 

## 2. Timing and synchronization 

#### Objective

To synchronize the processing across multiple devices with high precision. 

#### Methodology 

##### NTP implementation

Configure all devices with Network Time Protocol (NTP) to synchronize their system clocks. 

##### Multicast timestamp

To achieve higher precision for frame-level synchronization, create a custom multicast IP packet. This packet will be periodically broadcast across the network containing the current timestamp. Receivers will use this timestamp to align their processing pipelines. 

#### Testing setup 

What to test: Latency and jitter between devices. The difference in timestamps captured at various points in the processing chain. 

#### How to test 

Use high-resolution hardware timers on each board to record the receipt of multicast packets. 

Compare the timestamps to verify clock drift and measure synchronization accuracy. 

**Hardware** PYNQ-Z2, KV260, AUP-ZU3 

 

## 3. High-speed data transfer (RDMA) 

#### Objective

To achieve low-latency video data transfer between boards using Remote Direct Memory Access (RDMA). 

#### Methodology

##### RDMA implementation 

Use two KR260 boards, both equipped with RDMA-capable network interfaces. 

Configure the PL to receive the IP stream directly and write it into a memory buffer. 

Use the RDMA framework to transfer the video data from the memory of one KR260 directly into the memory of the second KR260, bypassing the CPU to minimize latency. 

##### Performance optimization

Profile and tune the RDMA parameters for maximum throughput and minimum latency for 8K video data. 

**Hardware** 2x KR260

 
## 4. 8K video stitching, compositing, and upscaling 

#### Objective

To combine multiple input streams into a single 8K output. 

#### Methodology

##### Decision point

Analyze the requirements for compositing (overlaying different video sources) versus stitching (seamlessly combining multiple camera views). The system architecture should be designed to handle both. 

#### Implementation

Develop PL-based video processing kernels for combining input streams, potentially including hardware acceleration for image warping and blending, depending on whether stitching or compositing is required. 

Explore 3D Surround View algorithms that correct for lens distortion and project multiple camera feeds into a unified 360-degree view. 

Implement a high-performance upscaling filter to convert the combined input streams into a single 8K output. 

UI for configuration: Extend the project's UI to allow a user to configure the layout and parameters for combining streams. 

**Hardware** KR260, KD240 

 
## 5. Video tiling 

#### Objective

To partition the 8K stream into smaller, manageable tiles for display. 

#### Methodology

##### 8K stream input

The 8K stream from the stitching/compositing stage serves as the input. 

##### Tiling logic

Develop a PL-based tiling engine to partition the 8K input into a 6x6 grid of 720p output streams. 

##### Output configuration

Each of the 36 tiles will be output as an independent stream. 

**Hardware** KR260, PYNQ-Z2 

 

## 6. Video display with overlay 

#### Objective

To display a 720p stream with debug information on a connected monitor. 

#### Methodology

##### IP stream input

Receive one of the 720p tiled IP streams. 

##### EDID reading

Implement an I2C controller in the processing system to read the Extended Display Identification Data (EDID) from the connected monitor. This allows the system to auto-configure supported resolutions. 

##### Video output

Generate the HDMI output signal for display. 

##### Overlay creation

Develop a hardware-accelerated overlay generator in the PL. This overlay will display real-time debug information (e.g., stream latency, frame rate, synchronization status) and measurement data without impacting the video stream's main processing pipeline. 

**Hardware** PYNQ-Z2 