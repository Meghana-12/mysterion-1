
PREFIX	?= arm-none-eabi
CC		= $(PREFIX)-gcc
LD		= $(PREFIX)-gcc
OBJCOPY	= $(PREFIX)-objcopy
OPENCM3_DIR = ../libopencm3

LDSCRIPT   = ../libopencm3/lib/stm32/f4/stm32f405x6.ld
LIBNAME    = opencm3_stm32f4
ARCH_FLAGS = -mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16
DEFINES    = -DSTM32F4
OBJS	   = stm32f4_wrapper.o wrapper.o

CFLAGS		+= -O2 \
		   -Wall -Wextra -Wimplicit-function-declaration \
		   -Wredundant-decls -Wmissing-prototypes -Wstrict-prototypes \
		   -Wundef -Wshadow \
		   -I$(OPENCM3_DIR)/include \
		   -fno-common $(ARCH_FLAGS) -MD $(DEFINES)
LDFLAGS		+= --static -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group \
		   -T$(LDSCRIPT) -nostartfiles -Wl,--gc-sections \
		   $(ARCH_FLAGS) \
		   -L$(OPENCM3_DIR)/lib

# Consider removing `lib` to speed this up

.PHONY: flash
flash: all
	st-flash write mysterion.bin 0x8000000

all: lib mysterion.bin


lib:
	make -C $(OPENCM3_DIR)

mysterion.bin: mysterion.elf
	$(OBJCOPY) -Obinary mysterion.elf mysterion.bin

mysterion.elf: mysterion.s $(OBJS) $(LDSCRIPT)
	$(LD) -o mysterion.elf mysterion.s $(OBJS) $(LDFLAGS) -l$(LIBNAME)

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

.PRECIOUS: %.elf

clean:
	rm -f *.bin
	rm -f *.elf
	rm -f *.d
	rm -f *.o

distclean:
	make clean
	make -C $(OPENCM3_DIR) clean
