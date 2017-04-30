## Build a patched jdk (with Docker)

```bash
$ make jdk10
$ ./output/jdk10/images/jdk/bin/java -version
java version "10-internal"
Java(TM) SE Runtime Environment (build 10-internal+0-adhoc..custom)
Java HotSpot(TM) 64-Bit Server VM (build 10-internal+0-adhoc..custom, mixed mode)
```

Patches are found in `./patches/<jdk_version>` and are buildroot relative, not
per sub-repo relative. That is to say, if you did work in `hotspot` the output
of your `hg export` would need to have `hotspot` prefixed before `src`.

The resulting image contains all the relevant bits in `/jdkbuild/custom` and if
no other command is supplied, when this image is run it will output to stdout
the contents of `/jdkbuild/custom/build/linux-x86_64-normal-server-release` as
a tarball.

(There are many "build container" patterns, and while Docker 17.05 supports
multi-stage builds, that does not accommodate for the notion of merely
extracting an artifact from a containerized build *without* also running that
container. So, instead of using a volume mount, or a `sleep` and a `docker cp`,
we opt for a lofi `tar c | base64` model. Caveat, you'll need to handle the
carriage return you get from the tty. If Docker had a `COPYOUT` directive that
could be used during a build step, we wouldn't need these gross hacks.)

After building the patched jdk, it will also launch a helloworld client that
depends on that particular version for building and running. This was useful
for my testing, but obviously is not strictly necessary.

## Build Customization

Valid Makefile variables:

 * JDK_UPDATE_VERSION - only valid on <= jdk8
 * JDK_BUILD_NUMBER - only valid on <= jdk8
 * JDK_BASE_URL - a url to pass to `get_source.sh`
 * JDK_CONFIGURE_ARGS - more arguments to pass to `configure`
 * EXTRA_RPMS - a list of other RPMS to install in the build environment

## Existing Patches

The supplied patches are existing work to improve the java diagnostic commands
against a target JVM running in a container.

`attach-namespace-aware` is needed for using `jstack` against a JVM running a
container will fail the attach sequence because:

  1. The wrong `pid` is used for the sequence, if the process from the "host"
  is observed as 17743 but when running inside a PID namespace the target JVM
  will believe its `pid` is 1. Thus, the wrong files are created and watched
  for and the attach sequence eventually times out and fails. The solution is
  to parse `NSpid` from `/proc/pid/status` and address the target JVM as `pid`.
  1. The attaching process assumes a shared filesystem which may not be true in
  the case of a containerized or chrooted process. The common work around for
  this is to address the process via `/proc/pid/root` which always presents a
  materialized view of the root filesystem as it relates to the process.

`agent-pid-relative` is needed for using `jmap` which attempts to resolve
symbols for the target JVM but assumes a shared filesystem. The same solution
exists here resolve pathnames relative to the process via `/proc/pid/root`.

Strictly speaking these changes are only necessary for the attaching process.
So, once you have a modified jstack you can address an already running and
containerized process.

### Notes

Some of `jmap`'s features can be unlcoked by setting `SA_ALTROOT` which will
resolve paths based on an explicit alternate root. If you're trying to use this
against a containerized JVM you could `export SA_ALTROOT=/proc/pid/root` and
some of `jmap` will work. However, some features also rely on the attach
sequence, so you'll need both patches.

The Linux ecosystem has a tendency to strip symbols which are necessary for
some of the features of `jmap`, so `jmap` may still appear to fail because the
container filesystem doesn't have the debuginfo necessary for resolving those
symbols.
