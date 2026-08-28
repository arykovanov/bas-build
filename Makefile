USE_OPCUA?=0
DEBUG?=0

MAKO=BAS/mako
MAKO_ZIP=BAS/mako.zip
VERSION=$(shell cat VERSION)
VERSION_MAKO=$(shell grep '^#define MAKO_VER' BAS/examples/MakoServer/src/MakoVer.h | awk '{print $$3}' | tr -d '"')
LUA_VERSION_MAJOR=$(shell grep '^#define LUA_VERSION_MAJOR_N' BAS/inc/lua.h | awk '{print $$3}')
LUA_VERSION_MINOR=$(shell grep '^#define LUA_VERSION_MINOR_N' BAS/inc/lua.h | awk '{print $$3}')
LUA_VERSION=$(LUA_VERSION_MAJOR).$(LUA_VERSION_MINOR)
LUA_VERSION_ENV=$(LUA_VERSION_MAJOR)_$(LUA_VERSION_MINOR)
DEB_HOST_ARCH?=$(shell dpkg-architecture -qDEB_HOST_ARCH)
DEB_HOST_MULTIARCH?=$(shell dpkg-architecture -qDEB_HOST_MULTIARCH)
LINTIAN?=lintian
LINTIAN_FLAGS?=--pedantic --fail-on error
BUILD_NUMBER ?=
PACKAGE_VERSION = $(VERSION_MAKO)$(BUILD_NUMBER)
LIBMAKO_STATIC_MODULE=$(TOP_DIR)/BAS/libmako.a

ifdef OPCUA_ROOT
OPCUA_BUILD_SOURCES = \
	$(OPCUA_ROOT)/opcua_packed.c \
	$(OPCUA_ROOT)/opcua_packed.h \
	$(OPCUA_ROOT)/opcua_ns0.c \
	$(OPCUA_ROOT)/opcua_ns0.h
endif

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
MAKO_RUNTIME_DIR = usr/lib/realtimelogic/mako
MAKO_INCLUDE_DIR = usr/include/realtimelogic
MAKO_LIB_DIR = usr/lib/$(DEB_HOST_MULTIARCH)

mako-deb: ${TMP_DIR} $(MAKO) $(MAKO_ZIP)
	@echo "Building mako runtime package..."
	rm -rf $(MAKO_DEB_DIR)
	install -d $(MAKO_DEB_DIR)/DEBIAN \
		$(MAKO_DEB_DIR)/$(MAKO_RUNTIME_DIR) \
		$(MAKO_DEB_DIR)/usr/bin \
		$(MAKO_DEB_DIR)/usr/lib/systemd/system \
		$(MAKO_DEB_DIR)/usr/share/man/man1 \
		$(MAKO_DEB_DIR)/etc/realtimelogic/mako \
		$(MAKO_DEB_DIR)/usr/share/doc/mako
	install -m 0755 $(MAKO) $(MAKO_DEB_DIR)/$(MAKO_RUNTIME_DIR)/mako
	strip --strip-unneeded $(MAKO_DEB_DIR)/$(MAKO_RUNTIME_DIR)/mako
	install -m 0644 $(MAKO_ZIP) $(MAKO_DEB_DIR)/$(MAKO_RUNTIME_DIR)/mako.zip
	install -m 0755 $(TOP_DIR)/dist/deb/mako/usr/bin/mako $(MAKO_DEB_DIR)/usr/bin/mako
	sed -i \
		-e 's/@LUA_VERSION@/$(LUA_VERSION)/g' \
		-e 's/@LUA_VERSION_ENV@/$(LUA_VERSION_ENV)/g' \
		-e 's/@DEB_HOST_MULTIARCH@/$(DEB_HOST_MULTIARCH)/g' \
		$(MAKO_DEB_DIR)/usr/bin/mako
	install -m 0644 $(TOP_DIR)/dist/deb/mako/etc/realtimelogic/mako/server.conf $(MAKO_DEB_DIR)/etc/realtimelogic/mako/server.conf
	install -m 0644 $(TOP_DIR)/dist/deb/mako/usr/lib/systemd/system/mako-server.service $(MAKO_DEB_DIR)/usr/lib/systemd/system/mako-server.service
	sed \
		-e 's/@PACKAGE_VERSION@/$(PACKAGE_VERSION)/g' \
		-e 's/@LUA_VERSION@/$(LUA_VERSION)/g' \
		-e 's/@LUA_VERSION_ENV@/$(LUA_VERSION_ENV)/g' \
		-e 's/@DEB_HOST_MULTIARCH@/$(DEB_HOST_MULTIARCH)/g' \
		$(TOP_DIR)/dist/deb/mako/usr/share/man/man1/mako.1 | gzip -9n > $(MAKO_DEB_DIR)/usr/share/man/man1/mako.1.gz
	chmod 0644 $(MAKO_DEB_DIR)/usr/share/man/man1/mako.1.gz
	install -m 0644 $(TOP_DIR)/dist/deb/copyright $(MAKO_DEB_DIR)/usr/share/doc/mako/copyright
	sed 's/@PACKAGE_VERSION@/$(PACKAGE_VERSION)/g' $(TOP_DIR)/dist/deb/changelog | gzip -9n > $(MAKO_DEB_DIR)/usr/share/doc/mako/changelog.gz
	chmod 0644 $(MAKO_DEB_DIR)/usr/share/doc/mako/changelog.gz
	install -m 0644 $(TOP_DIR)/dist/deb/mako/DEBIAN/control $(MAKO_DEB_DIR)/DEBIAN/control
	install -m 0644 $(TOP_DIR)/dist/deb/mako/DEBIAN/conffiles $(MAKO_DEB_DIR)/DEBIAN/conffiles
	install -m 0755 $(TOP_DIR)/dist/deb/mako/DEBIAN/config $(MAKO_DEB_DIR)/DEBIAN/config
	install -m 0755 $(TOP_DIR)/dist/deb/mako/DEBIAN/postinst $(MAKO_DEB_DIR)/DEBIAN/postinst
	install -m 0755 $(TOP_DIR)/dist/deb/mako/DEBIAN/prerm $(MAKO_DEB_DIR)/DEBIAN/prerm
	install -m 0755 $(TOP_DIR)/dist/deb/mako/DEBIAN/postrm $(MAKO_DEB_DIR)/DEBIAN/postrm
	install -m 0644 $(TOP_DIR)/dist/deb/mako/DEBIAN/templates $(MAKO_DEB_DIR)/DEBIAN/templates
	sed -i \
		-e 's/@PACKAGE_VERSION@/$(PACKAGE_VERSION)/g' \
		-e 's/@DEB_HOST_ARCH@/$(DEB_HOST_ARCH)/g' \
		-e 's/@LUA_VERSION@/$(LUA_VERSION)/g' \
		-e "s/@INSTALLED_SIZE@/$$(du -sk --exclude=DEBIAN $(MAKO_DEB_DIR) | cut -f1)/g" \
		$(MAKO_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --root-owner-group --build mako-${PACKAGE_VERSION} && cd -
	cp $(TMP_DIR)/mako-${PACKAGE_VERSION}.deb .
	$(LINTIAN) $(LINTIAN_FLAGS) mako-${PACKAGE_VERSION}.deb

mako-deb-dev: ${TMP_DIR} libmako
	@echo "Building mako-dev package..."
	rm -rf $(MAKO_DEV_DEB_DIR)
	install -d $(MAKO_DEV_DEB_DIR)/DEBIAN \
		$(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR) \
		$(MAKO_DEV_DEB_DIR)/$(MAKO_LIB_DIR)/pkgconfig \
		$(MAKO_DEV_DEB_DIR)/usr/share/doc/mako-dev
	cp -R $(TOP_DIR)/BAS/inc/. $(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR)/
	chmod -R a=rX,u+w $(MAKO_DEV_DEB_DIR)/$(MAKO_INCLUDE_DIR)
	install -m 0644 $(LIBMAKO_STATIC_MODULE) $(MAKO_DEV_DEB_DIR)/$(MAKO_LIB_DIR)/libmako.a
	install -m 0644 $(TOP_DIR)/dist/deb/mako-dev/usr/share/pkgconfig/mako.pc $(MAKO_DEV_DEB_DIR)/$(MAKO_LIB_DIR)/pkgconfig/mako.pc
	sed -i \
		-e 's/@VERSION_MAKO@/$(VERSION_MAKO)/g' \
		-e 's/@LUA_VERSION@/$(LUA_VERSION)/g' \
		-e 's/@DEB_HOST_MULTIARCH@/$(DEB_HOST_MULTIARCH)/g' \
		$(MAKO_DEV_DEB_DIR)/$(MAKO_LIB_DIR)/pkgconfig/mako.pc
	install -m 0644 $(TOP_DIR)/dist/deb/copyright $(MAKO_DEV_DEB_DIR)/usr/share/doc/mako-dev/copyright
	sed 's/@PACKAGE_VERSION@/$(PACKAGE_VERSION)/g' $(TOP_DIR)/dist/deb/changelog | gzip -9n > $(MAKO_DEV_DEB_DIR)/usr/share/doc/mako-dev/changelog.gz
	chmod 0644 $(MAKO_DEV_DEB_DIR)/usr/share/doc/mako-dev/changelog.gz
	install -m 0644 $(TOP_DIR)/dist/deb/mako-dev/DEBIAN/control $(MAKO_DEV_DEB_DIR)/DEBIAN/control
	sed -i \
		-e 's/@PACKAGE_VERSION@/$(PACKAGE_VERSION)/g' \
		-e 's/@DEB_HOST_ARCH@/$(DEB_HOST_ARCH)/g' \
		-e "s/@INSTALLED_SIZE@/$$(du -sk --exclude=DEBIAN $(MAKO_DEV_DEB_DIR) | cut -f1)/g" \
		$(MAKO_DEV_DEB_DIR)/DEBIAN/control
	cd $(TMP_DIR) && dpkg-deb --root-owner-group --build mako-dev-${PACKAGE_VERSION} && cd -
	cp $(TMP_DIR)/mako-dev-${PACKAGE_VERSION}.deb .
	$(LINTIAN) $(LINTIAN_FLAGS) mako-dev-${PACKAGE_VERSION}.deb

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

$(MAKO): $(OPCUA_BUILD_SOURCES)

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
