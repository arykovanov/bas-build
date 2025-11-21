MAKO=BAS/mako
MAKO_ZIP=BAS/mako.zip
VERSION=$(shell cat VERSION)
VERSION_MAKO=$(shell grep '^#define MAKO_VER' BAS/examples/MakoServer/src/MakoVer.h | awk '{print $$3}' | tr -d '"')

makefile_path = $(abspath $(lastword $(MAKEFILE_LIST)))
TOP_DIR=$(patsubst %/,%,$(dir $(makefile_path)))
TMP_DIR=${TOP_DIR}/.tmp


.PHONY: all mako mako-docker mako-docker-run

all: $(MAKO) $(MAKO_ZIP)

$(TMP_DIR):
	mkdir $(TMP_DIR)

dist: mako-docker

clean:
	rm -f $(MAKO) $(MAKO_ZIP)
	rm -f BAS/*.o
	rm -f BAS/examples/MakoServer/src/NewEncryptionKey.h
	rm -f BAS/src/shell.c BAS/src/sqlite3*
	docker rmi mako -f

dist-clean:
	docker rmi mako mako:${VERSION_MAKO}

dist-deb: mako-deb
MAKO_DEB_DIR = $(TMP_DIR)/mako-${VERSION_MAKO}
MAKO_DST_DIR = usr/lib/realtimelogic
MAKO_INCLUDE_DIR = usr/include/realtimelogic

mako-deb: ${TMP_DIR} $(MAKO) $(MAKO_ZIP)
	mkdir -p $(MAKO_DEB_DIR) $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	mkdir -p $(MAKO_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	mkdir -p $(MAKO_DEB_DIR)/usr/lib/pkgconfig
	cp -r $(TOP_DIR)/BAS/inc/* $(MAKO_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	cp -p $(MAKO_ZIP) $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -p ${MAKO} $(MAKO_DEB_DIR)/$(MAKO_DST_DIR)
	cp -r $(TOP_DIR)/dist/deb/* $(MAKO_DEB_DIR)
	sed 's/@VERSION_MAKO@/$(VERSION_MAKO)/g' $(TOP_DIR)/dist/deb/usr/lib/pkgconfig/mako.pc > $(MAKO_DEB_DIR)/usr/lib/pkgconfig/mako.pc
	echo "Version: ${VERSION_MAKO}" >> $(MAKO_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --build $(MAKO_DEB_DIR) && cd -
	cp $(TMP_DIR)/mako-${VERSION_MAKO}.deb .

mako: $(MAKO) $(MAKO_ZIP)

$(MAKO) $(MAKO_ZIP):
	./LinuxBuild.sh

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