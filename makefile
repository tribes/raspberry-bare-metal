PATH=/usr/local/gcc-arm-none-eabi/bin/

COMPILER=$(PATH)/arm-none-eabi-gcc

CPU=arm1176jzf-s

all: boot.o kernel.o kernel.elf

boot.o: boot.S
	$(COMPILER) -mcpu=$(CPU) -fpic -ffreestanding -c $^ -o $@

kernel.o: kernel.c
	$(COMPILER) -mcpu=$(CPU) -fpic -ffreestanding -std=gnu99 -c $^ -o $@ -O2 -Wall -Wextra

kernel.elf: boot.o kernel.o
	$(COMPILER) -T linker.ld -o $@ -ffreestanding -O2 -nostdlib $^
