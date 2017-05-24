#include "stm32wrapper.h"
#include <stdio.h>


extern int mysterion();


int main(void)
{
    clock_setup();
    gpio_setup();
    usart_setup(115200);

    char buf[128];
    snprintf(buf, sizeof buf, "Hello %i\n", mysterion());
    send_USART_str(buf);

    while(1);
    return 0;
}
