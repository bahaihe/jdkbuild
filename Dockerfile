FROM jdkbuildenv:latest

WORKDIR /jdkbuild/

ARG jdkVersion=jdk8u
RUN hg clone http://hg.openjdk.java.net/$jdkVersion/$jdkVersion custom

WORKDIR /jdkbuild/custom

ARG jdkBaseUrl
RUN bash get_source.sh $jdkBaseUrl

ADD patches /jdkbuild/patches
RUN find /jdkbuild/patches/$jdkVersion -name \*.patch -type f -exec patch -p1 -i '{}' \;

ENV DISABLE_HOTSPOT_OS_VERSION_CHECK=ok

ARG jdkUpdateVersion=121
ARG jdkBuildNumber=13
ARG jdkConfigureArgs
RUN bash configure \
      --with-update-version=$jdkUpdateVersion \
      --with-build-number=$jdkBuildNumber \
      $jdkConfigureArgs

RUN make images

CMD ["bash", "-c", "cd /jdkbuild/custom/build/linux-x86_64-normal-server-release/; tar cf - images | base64"]
