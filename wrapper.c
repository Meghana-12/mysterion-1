#include "stm32wrapper.h"
#include <stdio.h>
#include <inttypes.h>


extern int mysterion(uint8_t* state, uint8_t* key);


int main(void)
{
    char output[128];
    size_t i;

    clock_setup();
    gpio_setup();
    usart_setup(115200);

    uint8_t state[16] = {0};
    for (i = 0; i < 16; ++i) {
        state[i] = i;
    }
    uint8_t key[16] = {0};
    for (i = 0; i < 16; ++i) {
        key[i] = 42;
    }

    uint32_t ret = mysterion(state, key);
    snprintf(output, sizeof output, "'%i'\n", (int) ret);
    send_USART_str(output);

    while(1);
    return 0;
}
