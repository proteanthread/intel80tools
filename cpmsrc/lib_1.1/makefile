# path to root of build tree
ROOT := ..\..
TARGETS = lib.com
PEXFILE := lib.pex
REF=ref
PATCH = lib_1.1.patch
PROTECT = $(PATCH)

include $(ROOT)/tools/isis.mk

PLMFLAGS := OPTIMIZE CODE DEBUG
PLM80:=3.1
ASMFLAGS := DEBUG
LOCATEFLAGS:= PUBLICS SYMBOLS STACKSIZE(76)


OBJS = lib.obj rel.obj cmdlin.obj parsef.obj util.obj io.obj cpm.obj cpmvec.obj

.PHONY: all
all::
	$(MAKE) $(TARGETS)

%.com: %.abs $(PATCH)
	$(OBJBIN) $^ $@

%.abs: %.rel
	$(info $@ $^)
	$(call locate,$@,$^,CODE(100h) purge)

lib.rel: $(OBJS)
	$(call link,$@,$^ $(plm80.lib))

$(OBJS): lib.pex

print: all lib.abs
	perl $(ROOT)/tools/relst.pl lib.abs lib.map $(OBJS:.obj=.lst)
