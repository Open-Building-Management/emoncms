# Emoncms module makefile
# Copyright (C) 2021 Alexandre Cuer <alexandre.cuer at cerema dot fr>

module:
	@if [ ! -d "$(WWW)/emoncms/Modules/$(name)" ]; then\
		echo "Installing module $(name)";\
		cd $(WWW)/emoncms/Modules && git clone -b stable https://github.com/emoncms/$(name);\
	fi

symodule:
	@mkdir -p $(EMONCMS_DIR)/modules
	@if [ ! -d "$(EMONCMS_DIR)/modules/$(name)" ]; then\
		echo "Installing module $(name)";\
		cd $(EMONCMS_DIR)/modules && git clone -b stable https://github.com/emoncms/$(name);\
	fi
	@if [ -d $(EMONCMS_DIR)/modules/$(name)/$(name)-module ]; then\
        	echo "symlinking IU directory";\
        	ln -s $(EMONCMS_DIR)/modules/$(name)/$(name)-module $(WWW)/emoncms/Modules/$(name);\
	fi
