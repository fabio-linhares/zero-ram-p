# SPDX-License-Identifier: GPL-2.0
# Standalone Makefile for Zero RAM (Kernel Module com Rework de zcomp v2)

MODULE_NAME := zram

$(MODULE_NAME)-y := zcomp.o zram_drv.o \
                    backend_lzorle.o backend_lzo.o \
                    backend_lz4.o backend_lz4hc.o \
                    backend_zstd.o backend_deflate.o backend_842.o

obj-m := $(MODULE_NAME).o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod* .*.cmd modules.order Module.symvers

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a
