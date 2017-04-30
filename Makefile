JDK_VERSION ?= jdk8u
JDK_UPDATE_VERSION ?= 121
JDK_BUILD_NUMBER ?= 13
EXTRA_RPMS=

AVAILABLE_VERSIONS=jdk8u jdk9 jdk10

all: jdk10

buildenv:
	curl -O https://www.mercurial-scm.org/release/centos7/RPMS/x86_64/mercurial-3.9.2-1.x86_64.rpm
	for i in $(EXTRA_RPMS); do curl -O $$i; done
	docker build -t jdkbuildenv:latest -f Dockerfile.buildenv .
	rm -f *.rpm

$(AVAILABLE_VERSIONS):
	$(MAKE) -C . \
		JDK_VERSION=$@ \
		JDK_UPDATE_VERSION=${JDK_UPDATE_VERSION} \
		JDK_BUILD_NUMBER=${JDK_BUILD_NUMBER} \
		JDK_BASE_URL=${JDK_BASE_URL} \
		JDK_CONFIGURE_ARGS=${JDK_CONFIGURE_ARGS} \
		build client

build: buildenv
	docker build -t jdkbuild-${JDK_VERSION}:latest \
		--build-arg jdkVersion=${JDK_VERSION} \
		--build-arg jdkUpdateVersion=${JDK_UPDATE_VERSION} \
		--build-arg jdkBuildNumber=${JDK_BUILD_NUMBER} \
		--build-arg jdkBaseUrl=${JDK_BASE_URL} \
		--build-arg jdkConfigureArgs=${JDK_CONFIGURE_ARGS} \
		.
	rm -rf output/${JDK_VERSION} && mkdir -p output/${JDK_VERSION}
	cd output/${JDK_VERSION} && docker run --rm -it jdkbuild-${JDK_VERSION}:latest | sed 's/\r$$//' | base64 -d | tar x

client:
	cd helloworld && docker build -f Dockerfile.${JDK_VERSION} -t helloworld-${JDK_VERSION}:latest . && docker run --rm -it helloworld-${JDK_VERSION}:latest
