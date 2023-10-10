# Dockerfile port of https://gist.github.com/jcmvbkbc/316e6da728021c8ff670a24e674a35e6
# wifi details http://wiki.osll.ru/doku.php/etc:users:jcmvbkbc:linux-xtensa:esp32s3wifi

# we need python 3.10 not 3.11
FROM ubuntu:22.04

RUN apt-get update
RUN apt-get -y install gperf bison flex texinfo help2man gawk libtool-bin git unzip ncurses-dev rsync zlib1g zlib1g-dev xz-utils cmake wget bzip2 g++ python3 python3-dev python3-pip cpio bc virtualenv libusb-1.0 && \
    ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /app

# install autoconf 2.71
RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz && \
    tar -xf autoconf-2.71.tar.xz && \
    cd autoconf-2.71 && \
    ./configure --prefix=`pwd`/root && \
    make && \
    make install
ENV PATH="$PATH:/app/autoconf-2.71/root/bin"

# dynconfig
RUN git clone https://github.com/jcmvbkbc/xtensa-dynconfig -b original --depth=1 && \
    git clone https://github.com/jcmvbkbc/config-esp32s3 esp32s3 --depth=1 && \
    make -C xtensa-dynconfig ORIG=1 CONF_DIR=`pwd` esp32s3.so
ENV XTENSA_GNU_CONFIG="/app/xtensa-dynconfig/esp32s3.so"

# ct-ng cannot run as root, we'll just do everything else as a user
RUN useradd -d /app/build -u 3232 esp32 && mkdir build && chown esp32:esp32 build
USER esp32

# toolchain
RUN cd build && \
    git clone https://github.com/jcmvbkbc/crosstool-NG.git -b xtensa-fdpic --depth=1 && \
    cd crosstool-NG && \
    ./bootstrap && \
    ./configure --enable-local && \
    make && \
    ./ct-ng xtensa-esp32s3-linux-uclibcfdpic && \
    CT_PREFIX=`pwd`/builds ./ct-ng build || echo "Completed"  # the complete ct-ng build fails but we still get what we wanted!
RUN [ -e build/crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] || exit 1

#
# bootloader
#
ENV IDF_PATH="/app/build/esp-hosted/esp_hosted_ng/esp/esp_driver/esp-idf"
RUN cd build && \
git clone https://github.com/jcmvbkbc/esp-hosted -b ipc && \
cd esp-hosted/esp_hosted_ng/esp/esp_driver && \
cmake . && \
cd esp-idf && \
. ./export.sh && \
cd ../network_adapter && \
idf.py set-target esp32s3 && \
cp sdkconfig.defaults.esp32s3 sdkconfig && \
idf.py build

#
# kernel and rootfs
#
RUN cd build && \ 
	git clone https://github.com/jcmvbkbc/buildroot -b xtensa-2023.08-fdpic && \
	make -C buildroot O=`pwd`/build-buildroot-esp32s3 esp32s3_defconfig && \
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PATH `pwd`/crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic && \
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic' && \
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic' && \
	make -C buildroot O=`pwd`/build-buildroot-esp32s3

# keep docker running so we can debug/rebuild :)
USER root
ENTRYPOINT ["tail", "-f", "/dev/null"]

#
# flash
#
# activate idf.py with . ./export.sh
# copy bootloader.bin partition-table.bin network_adapter.bin xipImage rootfs.cramfs and etc.jffs2 to your host machine
# flash bootloader, partition table and network adapter
# esptool.py --chip esp32s3 -p /dev/ttyACM0 -b 921600 --before=default_reset --after=hard_reset write_flash 0x0 bootloader.bin 0x10000 network_adapter.bin 0x8000 partition-table.bin
# flash the system partitions
# parttool.py -p /dev/ttyACM0 -b 921600 write_partition --partition-name linux  --input xipImage
# parttool.py -p /dev/ttyACM0 -b 921600 write_partition --partition-name rootfs --input rootfs.cramfs
# parttool.py -p /dev/ttyACM0 -b 921600 write_partition --partition-name etc --input etc.jffs2
