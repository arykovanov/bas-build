MAKO=BAS/mako
MAKO_ZIP=BAS/mako.zip
VERSION=$(shell cat VERSION)
VERSION_MAKO=$(shell grep '^#define MAKO_VER' BAS/examples/MakoServer/src/MakoVer.h | awk '{print $$3}' | tr -d '"')

.PHONY: all mako mako-docker mako-docker-run

all: $(MAKO) $(MAKO_ZIP)

dist: mako-docker

clean:
	rm -f $(MAKO) $(MAKO_ZIP)
	rm -f BAS/*.o
	rm -f BAS/examples/MakoServer/src/NewEncryptionKey.h
	rm -f BAS/src/shell.c BAS/src/sqlite3*
	docker rmi mako -f

dist-clean:
	docker rmi mako mako:${VERSION_MAKO}

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
	echo ${VERSION_MAKO}