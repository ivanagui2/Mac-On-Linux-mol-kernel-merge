#
# Makefile for the Linux host MOL driver
#

obj-$(CONFIG_MOL)	:= _fault.o _dev.o _misc.o _mmu.o _hostirq.o init.o hash.o \
			   emu.o mmu.o mmu_fb.o mmu_io.o mmu_tracker.o skiplist.o \
		  	   mtable.o fault.o context.o ptaccess.o misc.o moldbg.o \
		   	   traps.o actions.o _performance.o 

mol-objs	:= $(PERFOBJS_) _performance.o
obj-y		:= _kuname.o mol.o 

PERFOBJS	= $(addprefix $(obj)/, $(PERFOBJS_))
MOL_ASMFLAGS	= $(CPPFLAGS) $(ASMFLAGS) $(INCLUDES) -D__ASSEMBLY__

T:="/tmp"

$(obj)/_traps.o:	$(src)/asm_offsets.h $(src)/traps.S $(src)/*.S $(src)/*.h

$(obj)/_fault.o: $(src)/.kuname
$(src)/.kuname: $(obj)/_kuname.o
	@strings $< | grep -- '-MAGIC-' | sed -e s/-MAGIC-// > $@

$(obj)/traps.o: $(obj)/_traps.o
	@$(src)/relcheck.pl $<
	@cp -f $< $@
	@$(STRIP) -S -x $@

$(obj)/_%.o: $(src)/%.S
	@echo "  AS [x]   $@"
	@rm -f $@ $@.s
	@$(CPP) $(MOL_ASMFLAGS) $< | m4 -s > $@.m4
	@ASFILTER="./asfilter" ; test -x $$ASFILTER || ASFILTER="tr ';' '\n'" ; \
	cat $@.m4 | $$ASFILTER > $@.s
	@$(AS) $@.s $(AS_FLAGS) -o $@
	@rm -f $@.s $@.m4


$(src)/asm_offsets.h:	$(src)/archinclude.h $(src)/kernel_vars.h $(src)/mac_registers.h
$(src)/asm_offsets.h:	$(src)/asm_offsets.c $(src)/asm_offsets.inc
	@rm -f ${T}/tmp-offsets.c $@ ; cat $^ > ${T}/tmp-offsets.c
	@$(CC) $(CPPFLAGS) $(CFLAGS) -I$(src) -Wall -S ${T}/tmp-offsets.c -o ${T}/tmp-offsets.s
	@echo "/* WARNING! Automatically generated from 'shared/asm_offsets.c' - DO NOT EDIT! */" > $@
	@grep '^#' ${T}/tmp-offsets.s >> $@
	@rm -f ${T}/tmp-offsets.*


$(src)/_performance.c: $(PERFOBJS)
	@rm -f $@ $@.tmp; echo "/* WARNING! DO NOT EDIT! AUTOMATICALLY GENERATED! */" > $@.tmp
	@echo "#include \"performance.h\"" >> $@.tmp
	@$(NM) $(PERFOBJS) | awk -- '/gPerf__/ { print "unsigned long "$$2";" }' >> $@.tmp
	@echo "perf_info_t g_perf_info_table[] = {" >> $@.tmp
	@$(NM) $(PERFOBJS) | awk -- '/gPerf__/ { print "  { \""$$2"\",&"$$2"}," }' >> $@.tmp
	@echo "  {0,0} };" >> $@.tmp
	@cat $@.tmp | sed s/_gPerf/gPerf/g > $@
	@rm -f $@.tmp
