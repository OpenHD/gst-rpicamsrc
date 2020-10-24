#!/bin/bash

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

PACKAGE_ARCH=$1
OS=$2
DISTRO=$3
BUILD_TYPE=$4

if [ "${BUILD_TYPE}" == "docker" ]; then
    cat << EOF > /etc/resolv.conf
options rotate
options timeout:1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
fi


PACKAGE_NAME=gst-rpicamsrc

TMPDIR=/tmp/${PACKAGE_NAME}-installdir

rm -rf ${TMPDIR}/*

mkdir -p ${TMPDIR}/usr/lib/arm-linux-gnueabihf/gstreamer-1.0 || exit 1

./autogen.sh --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ || exit 1
make || exit 1
cp src/.libs/libgstrpicamsrc.so ${TMPDIR}/usr/lib/arm-linux-gnueabihf/gstreamer-1.0/ || exit 1
cp src/.libs/libgstrpicamsrc.lai ${TMPDIR}/usr/lib/arm-linux-gnueabihf/gstreamer-1.0/ || exit 1


VERSION=$(git describe)

rm ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb > /dev/null 2>&1

fpm -a ${PACKAGE_ARCH} -s dir -t deb -n ${PACKAGE_NAME} -v ${VERSION//v} -C ${TMPDIR} \
  --after-install after-install.sh \
  -d "libgstreamer1.0-0" \
  -d "libgstreamer-plugins-base1.0-0" \
  -p ${PACKAGE_NAME}_VERSION_ARCH.deb || exit 1

#
# Only push to cloudsmith for tags. If you don't want something to be pushed to the repo, 
# don't create a tag. You can build packages and test them locally without tagging.
#
git describe --exact-match HEAD > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "Pushing package to OpenHD repository"
    cloudsmith push deb openhd/openhd-2-1/${OS}/${DISTRO} ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb || exit 1
else
    echo "Pushing package to OpenHD testing repository"
    cloudsmith push deb openhd/openhd-2-1-testing/${OS}/${DISTRO} ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb || exit 1
fi

