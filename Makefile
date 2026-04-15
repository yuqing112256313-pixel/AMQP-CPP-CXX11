PREFIX                  ?= /usr
INCLUDE_DIR             = ${PREFIX}/include
LIBRARY_DIR             = ${PREFIX}/lib
PACKAGE_DIR             ?= dist
PACKAGE_ROOT            = $(LIBRARY_NAME)-$(VERSION)
PACKAGE_NAME            = $(PACKAGE_ROOT)-shared.tar.gz
export LIBRARY_NAME		= amqpcpp
export SONAME			= 4.3
export VERSION			= 4.3.19

all:
		$(MAKE) -C src all

pure:
		$(MAKE) -C src pure

release:
		$(MAKE) -C src release

static:
		$(MAKE) -C src static

shared:
		$(MAKE) -C src shared

package-shared: shared
		mkdir -p $(PACKAGE_DIR)/$(PACKAGE_ROOT)/include/$(LIBRARY_NAME)/linux_tcp
		mkdir -p $(PACKAGE_DIR)/$(PACKAGE_ROOT)/lib
		cp -f include/$(LIBRARY_NAME).h $(PACKAGE_DIR)/$(PACKAGE_ROOT)/include
		cp -f include/amqpcpp/*.h $(PACKAGE_DIR)/$(PACKAGE_ROOT)/include/$(LIBRARY_NAME)
		cp -f include/amqpcpp/linux_tcp/*.h $(PACKAGE_DIR)/$(PACKAGE_ROOT)/include/$(LIBRARY_NAME)/linux_tcp
		cp -f src/lib$(LIBRARY_NAME).so.$(VERSION) $(PACKAGE_DIR)/$(PACKAGE_ROOT)/lib
		ln -s -f lib$(LIBRARY_NAME).so.$(VERSION) $(PACKAGE_DIR)/$(PACKAGE_ROOT)/lib/lib$(LIBRARY_NAME).so.$(SONAME)
		ln -s -f lib$(LIBRARY_NAME).so.$(VERSION) $(PACKAGE_DIR)/$(PACKAGE_ROOT)/lib/lib$(LIBRARY_NAME).so
		tar -czf $(PACKAGE_DIR)/$(PACKAGE_NAME) -C $(PACKAGE_DIR) $(PACKAGE_ROOT)
		@echo "Shared package created: $(PACKAGE_DIR)/$(PACKAGE_NAME)"

clean:
		$(MAKE) -C src clean
		$(RM) -r $(PACKAGE_DIR)

install:
		mkdir -p ${INCLUDE_DIR}/$(LIBRARY_NAME)
		mkdir -p ${INCLUDE_DIR}/$(LIBRARY_NAME)/linux_tcp
		mkdir -p ${LIBRARY_DIR}
		cp -f include/$(LIBRARY_NAME).h ${INCLUDE_DIR}
		cp -f include/amqpcpp/*.h ${INCLUDE_DIR}/$(LIBRARY_NAME)
		cp -f include/amqpcpp/linux_tcp/*.h ${INCLUDE_DIR}/$(LIBRARY_NAME)/linux_tcp
		-cp -f src/lib$(LIBRARY_NAME).so.$(VERSION) ${LIBRARY_DIR}
		-cp -f src/lib$(LIBRARY_NAME).a.$(VERSION) ${LIBRARY_DIR}
		ln -s -f lib$(LIBRARY_NAME).so.$(VERSION) $(LIBRARY_DIR)/lib$(LIBRARY_NAME).so.$(SONAME)
		ln -s -f lib$(LIBRARY_NAME).so.$(VERSION) $(LIBRARY_DIR)/lib$(LIBRARY_NAME).so
		ln -s -f lib$(LIBRARY_NAME).a.$(VERSION) $(LIBRARY_DIR)/lib$(LIBRARY_NAME).a
