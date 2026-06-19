#include <stdio.h>
#include <stdint.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"

// Replace this if your Vivado Address Editor shows a different base address
#define INV_SQRT_BASE_ADDR 0x43C00000

// Helper function to send float raw bits safely via uint32_t AXI bus
void hw_write_float(uint32_t offset, float val) {
    uint32_t *val_ptr = (uint32_t*)&val;
    Xil_Out32(INV_SQRT_BASE_ADDR + offset, *val_ptr);
}

// Helper function to read uint32_t AXI bus and interpret as float bits
float hw_read_float(uint32_t offset) {
    uint32_t bits = Xil_In32(INV_SQRT_BASE_ADDR + offset);
    float *float_ptr = (float*)&bits;
    return *float_ptr;
}

int main() {
    xil_printf("\r\n========================================\r\n");
    xil_printf("  Fast Inverse Square Root Accelerator\r\n");
    xil_printf("========================================\r\n");

    // Test cases
    float test_vectors[4] = {4.0f, 0.25f, 100.0f, 2.0f};

    for (int i = 0; i < 4; i++) {
        float test_val = test_vectors[i];
        
        // 1. Write the float to Register 0 (Offset 0x00)
        hw_write_float(0x00, test_val);
        
        // 2. Poll Register 2 (Offset 0x08) for data_valid == 1
        // (At 100MHz, an 11-cycle pipeline finishes faster than an AXI transaction, 
        //  but polling ensures robust hardware synchronization)
        while ((Xil_In32(INV_SQRT_BASE_ADDR + 0x08) & 0x00000001) == 0);
        
        // 3. Read the result from Register 1 (Offset 0x04)
        float result = hw_read_float(0x04);
        
        // Print out the result. 
        // Note: xil_printf doesn't support floating point formatting (%f) by default.
        // We use standard printf here.
        printf("Input: %8.4f  |  Hardware 1/sqrt(x) = %8.4f\r\n", test_val, result);
    }
    
    xil_printf("Done.\r\n");
    return 0;
}
