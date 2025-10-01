# Emoncms module makefile
# Copyright (C) 2021 Alexandre Cuer <alexandre.cuer at wanadoo dot fr>

ifndef $(addon_ref)
 addon_ref=stable
endif
ifndef $(WWW)
 WWW=/var/www
endif
ifndef $(EMONCMS_DIR)
 EMONCMS_DIR=/opt/emoncms
endif

module:
	@if [ ! -d "$(WWW)/emoncms/Modules/$(name)" ]; then \
		echo "Installing module $(name) at ref $(addon_ref)"; \
		cd $(WWW)/emoncms/Modules && git clone -b $(addon_ref) https://github.com/emoncms/$(name); \
	fi

symodule:
	@mkdir -p $(EMONCMS_DIR)/modules
	@if [ ! -d "$(EMONCMS_DIR)/modules/$(name)" ]; then \
		echo "Installing symodule $(name) at ref $(addon_ref)"; \
		cd $(EMONCMS_DIR)/modules && git clone -b $(addon_ref) $(SYMLINKED_MODULES_URL)/$(name); \
	fi
	@if [ -d $(EMONCMS_DIR)/modules/$(name)/$(name)-module ]; then \
		echo "symlinking IU directory"; \
		ln -s $(EMONCMS_DIR)/modules/$(name)/$(name)-module $(WWW)/emoncms/Modules/$(name); \
	fi

