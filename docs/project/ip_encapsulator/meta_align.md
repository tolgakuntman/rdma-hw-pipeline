# Metadata Alignment (`meta_align`)

## Problem Statement

Payload data and metadata arrive on separate interfaces and may not be
synchronized. Downstream logic requires metadata to be available before
payload processing begins.

## Solution

The `meta_align` module ensures:

- Metadata is captured once per packet
- Metadata is delivered before the first payload beat
- Payload timing is preserved

## Operation

1. Wait for valid metadata
2. Buffer metadata internally
3. Wait for first payload beat
4. Emit metadata and payload together
5. Forward remaining payload beats transparently

## Key Properties

- No payload buffering
- One metadata beat per packet
- Fully backpressure-aware
