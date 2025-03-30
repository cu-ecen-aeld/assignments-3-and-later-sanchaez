#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$(realpath $1)
	echo "Using passed directory ${OUTDIR} for output"
fi

echo "Making output"
mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # Add your kernel build steps here
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j 8 all 
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j 8 modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j 8 dtbs

    # link Image to OUTDIR for the test
    rm -f ${OUTDIR}/Image
    ln ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/Image
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi

echo "-- Creating necessary base directories"
mkdir -pv $OUTDIR/rootfs/{bin,dev,etc,home,lib,lib64,proc,sys,tmp,usr/{bin,sbin},var/{log}}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # Configure busybox
else
    cd busybox
fi

echo "-- Making and installing busybox"
make distclean
make defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j 8
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

cd "$OUTDIR"

echo "-- Adding library dependencies to rootfs"

echo "Library dependencies"
${CROSS_COMPILE}readelf -a "$OUTDIR/rootfs/bin/busybox" | grep "program interpreter"
${CROSS_COMPILE}readelf -a "$OUTDIR/rootfs/bin/busybox" | grep "Shared library"
function get-cross-lib-path() {
    echo "$(realpath $(${CROSS_COMPILE}gcc -print-file-name="$1"))"
}

# copy interpreter
cp $(get-cross-lib-path ld-linux-aarch64.so.1) ${OUTDIR}/rootfs/lib

# copy libs
libraryDependencies=("libm.so.6" "libresolv.so.2" "libc.so.6")
for lib in "${libraryDependencies[@]}"; do
    cp $(get-cross-lib-path $lib) ${OUTDIR}/rootfs/lib64
done

echo "-- Making device nodes"
sudo mknod -m 622 ${OUTDIR}/rootfs/dev/console c 5 1
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3

echo "-- Cleaning and build the writer utility"
cd "$FINDER_APP_DIR"
make clean
make CROSS_COMPILE=${CROSS_COMPILE} writer
chmod +x writer

echo "-- Copying the finder related scripts and executables to the /home directory on the target rootfs"
cp -av ${FINDER_APP_DIR}/{writer,writer.sh,finder.sh,finder-test.sh,autorun-qemu.sh} ${OUTDIR}/rootfs/home/
cp -avr ${FINDER_APP_DIR}/conf/ ${OUTDIR}/rootfs/home/

echo "-- Chown the root directory"
sudo chown -R root:root ${OUTDIR}/rootfs

echo "-- Creating initramfs.cpio.gz"
cd "${OUTDIR}/rootfs/"
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio