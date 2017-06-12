#include "stm32wrapper.h"
#include <inttypes.h>
#include <stdio.h>
#include <string.h>


extern int mysterion_encrypt(uint8_t* state, const uint8_t* key);
extern int mysterion_decrypt(uint8_t* state, const uint8_t* key);


int main(void)
{
    char output[80];
    unsigned int oldcycles, cycles;

    clock_setup();
    gpio_setup();
    usart_setup(115200);

    const uint8_t msg[] = {0x1, 0x1, 0x0, 0x0, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0x07, 0x18, 0x29, 0x3A, 0x4B, 0x5C, 0x6D};
    const uint8_t key[] = {0x2, 0x5, 0x6, 0x7,0x52, 0xF3, 0xE1, 0xF2, 0x13, 0x24, 0x35, 0x46,0x5B, 0x6C, 0x7D, 0x88};
    const uint8_t expected_ciphertext[] = {0xCD, 0x1A, 0x8E, 0x64, 0x00, 0x87, 0xC2, 0xDB, 0x38, 0x86, 0xE6, 0x46, 0xC7, 0xE3, 0x3D, 0xEF};
    uint8_t state[16];

    /* Do encryption */
    memcpy(state, msg, 16);
    oldcycles = DWT_CYCCNT;
    mysterion_encrypt(state, key);
    cycles = DWT_CYCCNT - oldcycles;
    if (memcmp(state, expected_ciphertext, 16) != 0) {
        snprintf(output, sizeof(output), "Bad encryption result");
    } else {
        snprintf(output, sizeof(output), "Encryption took %u cycles", cycles);
    }
    send_USART_str(output);

    /* Do decryption */
    oldcycles = DWT_CYCCNT;
    mysterion_decrypt(state, key);
    cycles = DWT_CYCCNT - oldcycles;
    if (memcmp(state, msg, 16) != 0) {
        snprintf(output, sizeof(output), "Bad decryption result");
    } else {
        snprintf(output, sizeof(output), "Decryption took %u cycles", cycles);
    }
    send_USART_str(output);

    /* Print newline at the end of the output */
    send_USART_str("");

    while(1);
    return 0;
}
