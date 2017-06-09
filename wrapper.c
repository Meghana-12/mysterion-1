#include "stm32wrapper.h"
#include <stdio.h>
#include <inttypes.h>


extern int mysterion(uint8_t* state, uint8_t* key);


int main(void)
{
    char output[500];
    uint32_t ret;

    clock_setup();
    gpio_setup();
    usart_setup(115200);

    uint8_t state[] = {0x1, 0x1, 0x0, 0x0, 0xB2, 0xC3, 0xD4, 0xE5,0xF6, 0x07, 0x18, 0x29,0x3A, 0x4B, 0x5C, 0x6D};
    uint8_t key[] = {0x2, 0x5, 0x6, 0x7,0x52, 0xF3, 0xE1, 0xF2,0x13, 0x24, 0x35, 0x46,0x5B, 0x6C, 0x7D, 0x88};

    snprintf(output, sizeof output, "[%02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx]\n",
        state[0], state[1], state[2], state[3], state[4], state[5],
        state[6], state[7], state[8], state[9], state[10], state[11],
        state[12], state[13], state[14], state[15]);
    send_USART_str(output);

    ret = mysterion(state, key);
    snprintf(output, sizeof output, "[%02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx, %02hhx]\n",
        state[0], state[1], state[2], state[3], state[4], state[5],
        state[6], state[7], state[8], state[9], state[10], state[11],
        state[12], state[13], state[14], state[15]);
    send_USART_str(output);

    snprintf(output, sizeof output, "%u", ret);
    send_USART_str(output);

    while(1);
    return 0;
}
