USE_OPCUA?=0
DEBUG?=0

MAKO=BAS/mako
MAKO_ZIP=BAS/mako.zip
VERSION=$(shell cat VERSION)
VERSION_MAKO=$(shell grep '^#define MAKO_VER' BAS/examples/MakoServer/src/MakoVer.h | awk '{print $$3}' | tr -d '"')
BUILD_NUMBER ?=
PACKAGE_VERSION = $(VERSION_MAKO)$(BUILD_NUMBER)
LIBMAKO_STATIC_MODULE=$(TOP_DIR)/BAS/libmako.a

makefile_path = $(abspath $(lastword $(MAKEFILE_LIST)))
TOP_DIR=$(patsubst %/,%,$(dir $(makefile_path)))
TMP_DIR=${TOP_DIR}/.tmp


.PHONY: all mako mako-docker mako-docker-run mako-deb mako-deb-dev libmako check

all: $(MAKO) $(MAKO_ZIP) $(LIBMAKO_STATIC_MODULE)

$(TMP_DIR):
	mkdir $(TMP_DIR)

dist: mako-docker dist-deb

clean:
	rm -f $(MAKO) $(MAKO_ZIP)
	make -C BAS clean -f mako.mk
	rm -f BAS/libmako.a
	rm -f BAS/examples/MakoServer/src/NewEncryptionKey.h
	rm -f BAS/src/shell.c BAS/src/sqlite3*
	rm -f mako-*.deb mako-dev-*.deb
	rm -rf $(TMP_DIR)
	rm -rf BAS-Resources/build/mako.zip

dist-clean:
	docker rmi mako mako:${PACKAGE_VERSION}
	rm -rf $(TMP_DIR)/mako-*

dist-deb: mako-deb mako-deb-dev

MAKO_DEB_DIR = $(TMP_DIR)/mako-${PACKAGE_VERSION}
MAKO_DEV_DEB_DIR = $(TMP_DIR)/mako-dev-${PACKAGE_VERSION}
MAKO_DST_DIR = usr/bin
MAKO_INCLUDE_DIR = usr/include/realtimelogic

mako-deb: ${TMP_DIR} $(MAKO) $(MAKO_ZIP)
	@echo "Building mako runtime package..."
	mkdir -p $(MAKO_DEB_DIR) $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -p $(MAKO_ZIP) $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -p ${MAKO} $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -r $(TOP_DIR)/dist/deb/mako/* $(MAKO_DEB_DIR)
	sed -i '/^Package:/a Version: $(PACKAGE_VERSION)' $(MAKO_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --build mako-${PACKAGE_VERSION} && cd -
	cp $(TMP_DIR)/mako-${PACKAGE_VERSION}.deb .

mako-deb-dev: ${TMP_DIR} libmako
	@echo "Building mako-dev package..."
	mkdir -p $(MAKO_DEV_DEB_DIR) $(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	mkdir -p $(MAKO_DEV_DEB_DIR)/usr/share/pkgconfig
	cp -r $(TOP_DIR)/BAS/inc/* $(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	cp -r $(TOP_DIR)/dist/deb/mako-dev/* $(MAKO_DEV_DEB_DIR)

	mkdir -p $(MAKO_DEV_DEB_DIR)/usr/lib/realtimelogic
	cp -p $(LIBMAKO_STATIC_MODULE) $(MAKO_DEV_DEB_DIR)/usr/lib/realtimelogic
	
	sed 's/@VERSION_MAKO@/$(VERSION_MAKO)/g' $(TOP_DIR)/dist/deb/mako-dev/usr/share/pkgconfig/mako.pc > $(MAKO_DEV_DEB_DIR)/usr/share/pkgconfig/mako.pc
	sed -i '/^Package:/a Version: $(PACKAGE_VERSION)' $(MAKO_DEV_DEB_DIR)/DEBIAN/control
	sed -i 's/\$${binary:Version}/$(PACKAGE_VERSION)/g' $(MAKO_DEV_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --build mako-dev-${PACKAGE_VERSION} && cd -
	cp $(TMP_DIR)/mako-dev-${PACKAGE_VERSION}.deb .

mako: $(MAKO) $(MAKO_ZIP)


$(LIBMAKO_STATIC_MODULE): $(MAKO)
	ls $(TOP_DIR)/BAS/*.o -Al > /dev/null
	$(AR) rcs $(LIBMAKO_STATIC_MODULE) $(TOP_DIR)/BAS/*.o

libmako: $(LIBMAKO_STATIC_MODULE)

BAS/src/sqlite3.c:
	cp -f $(TOP_DIR)/sqlite/sqlite3.c $(TOP_DIR)/BAS/src/sqlite3.c
	cp -f $(TOP_DIR)/sqlite/sqlite3.h $(TOP_DIR)/BAS/src/sqlite3.h
	cp -f $(TOP_DIR)/sqlite/sqlite3ext.h $(TOP_DIR)/BAS/src/sqlite3ext.h

$(MAKO) $(MAKO_ZIP): BAS/src/sqlite3.c
	echo "n" | CFLAGS="-fPIC" USE_OPCUA=${USE_OPCUA} DEBUG=${DEBUG} ${MAKE} -C BAS -f mako.mk

dist-docker: Dockerfile ${MAKO} $(MAKO_ZIP)
	docker build -t mako -t mako:${PACKAGE_VERSION} -f Dockerfile ./BAS/
	if [ -n "${MAKO_DOCKER_REGISTRY}" ] ; then \
		docker tag mako:${PACKAGE_VERSION} ${MAKO_DOCKER_REGISTRY}/mako:${PACKAGE_VERSION} && \
		docker push ${MAKO_DOCKER_REGISTRY}/mako:${PACKAGE_VERSION} ; \
	fi

mako-docker-run: dist-docker
	docker run -it mako:${PACKAGE_VERSION}

mako-version:
	@echo ${VERSION_MAKO}

check: mako
	python3 -m unittest discover -s tests
