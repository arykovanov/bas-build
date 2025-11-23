USE_OPCUA ?= 0

MAKO=BAS/mako
MAKO_ZIP=BAS/mako.zip
VERSION=$(shell cat VERSION)
VERSION_MAKO=$(shell grep '^#define MAKO_VER' BAS/examples/MakoServer/src/MakoVer.h | awk '{print $$3}' | tr -d '"')

makefile_path = $(abspath $(lastword $(MAKEFILE_LIST)))
TOP_DIR=$(patsubst %/,%,$(dir $(makefile_path)))
TMP_DIR=${TOP_DIR}/.tmp


.PHONY: all mako mako-docker mako-docker-run mako-deb mako-deb-dev

all: $(MAKO) $(MAKO_ZIP)

$(TMP_DIR):
	mkdir $(TMP_DIR)

dist: mako-docker dist-deb

clean:
	rm -f $(MAKO) $(MAKO_ZIP)
	rm -f BAS/*.o
	rm -f BAS/examples/MakoServer/src/NewEncryptionKey.h
	rm -f BAS/src/shell.c BAS/src/sqlite3*
	rm -f mako-*.deb mako-dev-*.deb
	rm -rf $(TMP_DIR)
	if [ -f $(TOP_DIR)/BAS/mako.mk.orig ]; then \
		mv $(TOP_DIR)/BAS/mako.mk.orig $(TOP_DIR)/BAS/mako.mk ; \
	fi
	# docker rmi mako -f

dist-clean:
	docker rmi mako mako:${VERSION_MAKO}

dist-deb: mako-deb mako-deb-dev

MAKO_DEB_DIR = $(TMP_DIR)/mako-${VERSION_MAKO}
MAKO_DEV_DEB_DIR = $(TMP_DIR)/mako-dev-${VERSION_MAKO}
MAKO_DST_DIR = usr/bin
MAKO_INCLUDE_DIR = usr/include/realtimelogic

mako-deb: ${TMP_DIR} $(MAKO) $(MAKO_ZIP)
	@echo "Building mako runtime package..."
	mkdir -p $(MAKO_DEB_DIR) $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -p $(MAKO_ZIP) $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -p ${MAKO} $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -r $(TOP_DIR)/dist/deb/mako/* $(MAKO_DEB_DIR)
	sed -i '/^Package:/a Version: $(VERSION_MAKO)' $(MAKO_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --build mako-${VERSION_MAKO} && cd -
	cp $(TMP_DIR)/mako-${VERSION_MAKO}.deb .

mako-deb-dev: ${TMP_DIR}
	@echo "Building mako-dev package..."
	mkdir -p $(MAKO_DEV_DEB_DIR) $(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	mkdir -p $(MAKO_DEV_DEB_DIR)/usr/share/pkgconfig
	cp -r $(TOP_DIR)/BAS/inc/* $(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	cp -r $(TOP_DIR)/dist/deb/mako-dev/* $(MAKO_DEV_DEB_DIR)
	sed 's/@VERSION_MAKO@/$(VERSION_MAKO)/g' $(TOP_DIR)/dist/deb/mako-dev/usr/share/pkgconfig/mako.pc > $(MAKO_DEV_DEB_DIR)/usr/share/pkgconfig/mako.pc
	sed -i '/^Package:/a Version: $(VERSION_MAKO)' $(MAKO_DEV_DEB_DIR)/DEBIAN/control
	sed -i 's/\$${binary:Version}/$(VERSION_MAKO)/g' $(MAKO_DEV_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --build mako-dev-${VERSION_MAKO} && cd -
	cp $(TMP_DIR)/mako-dev-${VERSION_MAKO}.deb .

mako: $(MAKO) $(MAKO_ZIP)

$(MAKO) $(MAKO_ZIP):
	if [ "$(USE_OPCUA)" -eq 0 ]; then \
	  if [ ! -f $(TOP_DIR)/BAS/mako.mk.orig ]; then \
			cp $(TOP_DIR)/BAS/mako.mk $(TOP_DIR)/BAS/mako.mk.orig ; \
	  fi ; \
		sed 's/-DUSE_OPCUA=1/-DUSE_OPCUA=0/g' $(TOP_DIR)/BAS/mako.mk.orig > $(TOP_DIR)/BAS/mako.mk ; \
	else \
		if [ -f $(TOP_DIR)/BAS/mako.mk.orig ]; then \
			mv $(TOP_DIR)/BAS/mako.mk.orig $(TOP_DIR)/BAS/mako.mk ; \
		fi ; \
	fi

	./LinuxBuild.sh

	if [ "$(USE_OPCUA)" -eq 0 ]; then \
		zip -d $(MAKO_ZIP) '.lua/opcua/*' ; \
	fi

dist-docker: $(MAKO) $(MAKO_ZIP)
	docker build -t mako -t mako:${VERSION_MAKO} -f Dockerfile ./BAS/
	if [ -n "${MAKO_DOCKER_REGISTRY}" ]; then \
		docker tag mako:${VERSION_MAKO} ${MAKO_DOCKER_REGISTRY}/mako:${VERSION_MAKO} && \
		docker push ${MAKO_DOCKER_REGISTRY}/mako:${VERSION_MAKO} ; \
	fi

mako-docker-run: mako-docker
	docker run -it mako:${VERSION_MAKO}

mako-version:
	@echo ${VERSION_MAKO}