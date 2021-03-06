ifndef ____nmk_defined__build

#
# General helpers for simplified Makefiles.
#
src		:= $(obj)
src-makefile	:= $(call objectify,$(makefile))
obj-y		:=
lib-y		:=
target          :=
deps-y		:=
all-y		:=
builtin-name	:=
lib-name	:=
ld_flags	:=
cleanup-y	:=
mrproper-y	:=
objdirs		:=
libso-y	        :=

MAKECMDGOALS := $(call uniq,$(MAKECMDGOALS))

ifndef obj
        $(error obj is undefined)
endif

#
# Accumulate common flags.
define nmk-ccflags
        $(CFLAGS) $(ccflags-y) $(CFLAGS_$(@F))
endef

define nmk-asflags
        $(CFLAGS) $(AFLAGS) $(asflags-y) $(AFLAGS_$(@F))
endef

define nmk-host-ccflags
        $(HOSTCFLAGS) $(host-ccflags-y) $(HOSTCFLAGS_$(@F))
endef

#
# General rules.
define gen-cc-rules
$(1).o: $(2).c $(src-makefile)
	$$(call msg-cc, $$@)
	$$(Q) $$(CC) -c $$(strip $$(nmk-ccflags)) $$< -o $$@
$(1).i: $(2).c $(src-makefile)
	$$(call msg-cc, $$@)
	$$(Q) $$(CC) -E $$(strip $$(nmk-ccflags)) $$< -o $$@
$(1).s: $(2).c $(src-makefile)
	$$(call msg-cc, $$@)
	$$(Q) $$(CC) -S -fverbose-asm $$(strip $$(nmk-ccflags)) $$< -o $$@
$(1).d: $(2).c $(src-makefile)
	$$(call msg-dep, $$@)
	$$(Q) $$(CC) -M -MT $$@ -MT $$(patsubst %.d,%.o,$$@) $$(strip $$(nmk-ccflags)) $$< -o $$@
$(1).o: $(2).S $(src-makefile)
	$$(call msg-cc, $$@)
	$$(Q) $$(CC) -c $$(strip $$(nmk-asflags)) $$< -o $$@
$(1).i: $(2).S $(src-makefile)
	$$(call msg-cc, $$@)
	$$(Q) $$(CC) -E $$(strip $$(nmk-asflags)) $$< -o $$@
$(1).d: $(2).S $(src-makefile)
	$$(call msg-dep, $$@)
	$$(Q) $$(CC) -M -MT $$@ -MT $$(patsubst %.d,%.o,$$@) $$(strip $$(nmk-asflags)) $$< -o $$@
endef

include $(src-makefile)

ifneq ($(strip $(target)),)
	target := $(sort $(call uniq,$(target)))
endif

#
# Prepare the unique entries.
obj-y           := $(sort $(call uniq,$(obj-y)))
lib-y           := $(filter-out $(obj-y),$(sort $(call uniq,$(lib-y))))

#
# Add subdir path
obj-y           := $(call objectify,$(obj-y))
lib-y           := $(call objectify,$(lib-y))

#
# Strip custom names.
lib-name	:= $(strip $(lib-name))
builtin-name	:= $(strip $(builtin-name))

#
# Link flags.
ld_flags	:= $(strip $(LDFLAGS) $(ldflags-y))

#
# $(obj) related rules.
$(eval $(call gen-cc-rules,$(obj)/%,$(obj)/%))

#
# Prepare targets.
ifneq ($(lib-y),)
        lib-target :=
        ifneq ($(lib-name),)
                lib-target := $(obj)/$(lib-name)
        else
                lib-target := $(obj)/lib.a
        endif
        cleanup-y += $(call cleanify,$(lib-y))
        cleanup-y += $(lib-target)
        all-y += $(lib-target)
        objdirs += $(dir $(lib-y))
endif

ifneq ($(obj-y),)
        builtin-target :=
        ifneq ($(builtin-name),)
                builtin-target := $(obj)/$(builtin-name)
        else
                builtin-target := $(obj)/built-in.o
        endif
        cleanup-y += $(call cleanify,$(obj-y))
        cleanup-y += $(builtin-target)
        all-y += $(builtin-target)
        objdirs += $(dir $(obj-y))
endif

#
# Helpers for targets.
define gen-ld-target-rule
$(1): $(3)
	$$(call msg-link, $$@)
	$$(Q) $$(LD) $(2) -r -o $$@ $(4)
endef

define gen-ar-target-rule
$(1): $(3)
	$$(call msg-ar, $$@)
	$$(Q) $$(AR) -rcs$(2) $$@ $(4)
endef

#
# Predefined (builtins) targets rules.
ifdef builtin-target
        $(eval $(call gen-ld-target-rule,                               \
                        $(builtin-target),                              \
                        $(ld_flags),                                    \
                        $(obj-y) $(src-makefile),                       \
                        $(obj-y) $(call objectify,$(obj-e))))
endif

ifdef lib-target
        $(eval $(call gen-ar-target-rule,                               \
                        $(lib-target),                                  \
                        $(ARFLAGS) $(arflags-y),                        \
                        $(lib-y) $(src-makefile),                       \
                        $(lib-y) $(call objectify,$(lib-e))))
endif

#
# Custom targets rules.
define gen-custom-target-rule
        ifneq ($($(1)-obj-y),)
                $(eval $(call gen-ld-target-rule,                       \
                                $(obj)/$(1).built-in.o,                 \
                                $(ld_flags) $(LDFLAGS_$(1)),            \
                                $(call objectify,$($(1)-obj-y))         \
                                $(src-makefile),                        \
                                $(call objectify,$($(1)-obj-y))         \
                                $(call objectify,$($(1)-obj-e))))
                all-y += $(obj)/$(1).built-in.o
                cleanup-y += $(call cleanify,$(call objectify,$($(1)-obj-y)))
                cleanup-y += $(obj)/$(1).built-in.o
                objdirs += $(dir $(call objectify,$($(1)-obj-y)))
        endif
        ifneq ($($(1)-lib-y),)
                $(eval $(call gen-ar-target-rule,                       \
                                $(obj)/$(1).lib.a,                      \
                                $(ARFLAGS) $($(1)-arflags-y),           \
                                $(call objectify,$($(1)-lib-y))         \
                                $(src-makefile),                        \
                                $(call objectify,$($(1)-lib-y)))        \
                                $(call objectify,$($(1)-lib-e)))
                all-y += $(obj)/$(1).lib.a
                cleanup-y += $(call cleanify,$(call objectify,$($(1)-lib-y)))
                cleanup-y += $(obj)/$(1).lib.a
                objdirs += $(dir $(call objectify,$($(1)-lib-y)))
        endif
endef

$(foreach t,$(target),$(eval $(call gen-custom-target-rule,$(t))))

#
# Prepare rules for dirs other than (obj)/.
objdirs := $(patsubst %/,%,$(filter-out $(obj)/,$(call uniq,$(objdirs))))
$(foreach t,$(objdirs),$(eval $(call gen-cc-rules,$(t)/%,$(t)/%)))

#
# Host programs.
define gen-host-cc-rules
$(addprefix $(obj)/,$(1)): $(obj)/%.o: $(obj)/%.c $(src-makefile)
	$$(call msg-host-cc, $$@)
	$$(Q) $$(HOSTCC) -c $$(strip $$(nmk-host-ccflags)) $$< -o $$@
$(patsubst %.o,%.i,$(addprefix $(obj)/,$(1))): $(obj)/%.i: $(obj)/%.c $(src-makefile)
	$$(call msg-host-cc, $$@)
	$$(Q) $$(HOSTCC) -E $$(strip $$(nmk-host-ccflags)) $$< -o $$@
$(patsubst %.o,%.s,$(addprefix $(obj)/,$(1))): $(obj)/%.s: $(obj)/%.c $(src-makefile)
	$$(call msg-host-cc, $$@)
	$$(Q) $$(HOSTCC) -S -fverbose-asm $$(strip $$(nmk-host-ccflags)) $$< -o $$@
$(patsubst %.o,%.d,$(addprefix $(obj)/,$(1))): $(obj)/%.d: $(obj)/%.c $(src-makefile)
	$$(call msg-host-dep, $$@)
	$$(Q) $$(HOSTCC) -M -MT $$@ -MT $$(patsubst %.d,%.o,$$@) $$(strip $$(nmk-host-ccflags)) $$< -o $$@
endef

define gen-host-rules
        $(eval $(call gen-host-cc-rules,$($(1)-objs)))
        all-y += $(addprefix $(obj)/,$($(1)-objs))
        cleanup-y += $(call cleanify,$(addprefix $(obj)/,$($(1)-objs)))
$(obj)/$(1): $(addprefix $(obj)/,$($(1)-objs)) $(src-makefile)
	$$(call msg-host-link, $$@)
	$$(Q) $$(HOSTCC) $$(HOSTCFLAGS) $(addprefix $(obj)/,$($(1)-objs)) $$(HOSTLDFLAGS) $$(HOSTLDFLAGS_$$(@F))-o $$@
all-y += $(obj)/$(1)
cleanup-y += $(obj)/$(1)
endef
$(foreach t,$(hostprogs-y),$(eval $(call gen-host-rules,$(t))))

#
# Dynamic library linking.
define gen-so-link-rules
$(call objectify,$(1)).so:  $(call objectify,$($(1)-objs)) $(src-makefile)
	$$(call msg-link, $$@)
	$$(Q) $$(CC) -shared $$(ldflags-so) $$(LDFLAGS) $$(LDFLAGS_$$(@F)) -o $$@ $(call objectify,$($(1)-objs))
all-y += $(call objectify,$(1)).so
cleanup-y += $(call objectify,$(1)).so
endef
$(foreach t,$(libso-y),$(eval $(call gen-so-link-rules,$(t))))

#
# Figure out if the target we're building needs deps to include.
define collect-deps
        ifneq ($(filter-out %.d,$(1)),)
                ifneq ($(filter %.o %.i %.s,$(1)),)
                        deps-y += $(addsuffix .d,$(basename $(1)))
                endif
        endif
        ifeq ($(builtin-target),$(1))
                deps-y += $(obj-y:.o=.d)
        endif
        ifeq ($(lib-target),$(1))
                deps-y += $(lib-y:.o=.d)
        endif
        ifneq ($(filter all $(all-y) $(hostprogs-y),$(1)),)
                deps-y += $(obj-y:.o=.d)
                deps-y += $(lib-y:.o=.d)
                deps-y += $(foreach t,$(target),$(call objectify,$($(t)-lib-y:.o=.d)) $(call objectify,$($(t)-obj-y:.o=.d)))
                deps-y += $(foreach t,$(hostprogs-y),$(addprefix $(obj)/,$($(t)-objs:.o=.d)))
        endif
endef

ifneq ($(MAKECMDGOALS),)
        ifneq ($(MAKECMDGOALS),clean)
                $(foreach goal,$(MAKECMDGOALS),$(eval $(call collect-deps,$(goal))))
                deps-y := $(call uniq,$(deps-y))
                ifneq ($(deps-y),)
                        $(eval -include $(deps-y))
                endif
        endif
endif

#
# Main phony rule.
all: $(all-y)
	@true
.PHONY: all

#
# Clean most files, but leave enough to navigate with tags (generated files)
clean:
	$(call msg-clean, $(obj))
	$(Q) $(RM) $(cleanup-y)
.PHONY: clean

#
# Delete all generated files
mrproper: clean
	$(Q) $(RM) $(mrproper-y)
.PHONY: mrproper

#
# Footer.
____nmk_defined__build = y
endif
