# Build the ESP32 Linux Kernel

**PAY ATTENTION:** IF YOUR ESP32's CHIP IS NOT IN REVISION v3.00 TO v3.9 DO NOT FLASH OR YOU WILL **BRICK** YOUR DEVICE!!!

Based on the [Max Filippov ESP32-S3 Kernel Linux Build Scripts](https://github.com/jcmvbkbc/esp32-linux-build) and the [Antonio Docker Container](https://github.com/hpsaturn/esp32s3-linux) with a few modifications to make it work for me.

You will need:

- an operating system with [Docker Support](https://www.docker.com/); and
- [esp-idf](https://github.com/espressif/esp-idf) (optional if you choose the second flash method)

Check [This Wiki Page](http://wiki.osll.ru/doku.php/etc:users:jcmvbkbc:linux-xtensa:esp32s3) to see what is working.

## Build Instructions

```text
sudo docker build -t esp32-linux .
```

Build time lasts for around an hour to be completed, you will have a ~23GB docker image with the binaries needed to flash the ESP32.

Identify in your computer where is the serial port to the ESP32, I will suppose it will by `/dev/ttyACM0`:

```text
# give device access (ownership) to you current user
sudo chown $USER /dev/ttyACM0
```

Mount a container with the image you have just built from Dockerfile:

```text
sudo docker run -it esp32-linux
```

Copy the container ID (let us suppose it is `78bdc7c38626`) and copy the generated binaries to your native environment:

```text
sudo docker cp 78bdc7c38626:/app/build/esp-idf/examples/get-started/linux_boot:.
sudo docker cp 78bdc7c38626:build-buildroot-esp32/images/xipImage:./build
sudo docker cp 78bdc7c38626:build-buildroot-esp32/images/rootfs.cramfs:./build
```

You may now delete the docker image and container, you won't need it anymore (if you don't want to cross compile any application).

## Flash Instructions

### First Method

This method copies the binaries from container to main system environment (outside docker), and then flashes using native `esp-idf`.

Activate `esp-idf` environment wherever it have been installed, I will suppose it is installed in `/opt/esp-idf`:

```text
. /opt/esp-idf/export.sh
```

Then navigate to `build` folder and run:

```text
cd build
esptool.py --chip esp32 -p /dev/ttyACM0 -b 460800 --before=default_reset --after=hard_reset write_flash --flash_mode dio --flash_freq 80m --flash_size 4MB 0x1000 bootloader/bootloader.bin 0x10000 linux_boot.bin 0x8000 partition_table/partition-table.bin
parttool.py 460800 write_partition --partition-name linux  --input xipImage
parttool.py 460800 write_partition --partition-name rootfs --input rootfs.cramfs
```

### Second Method

This method installs `esp-idf` inside docker container, it will requires to passthrough serial device to the running docker container in order to flash.

Supposing your USB to UART adapter is listed in your PC as `/dev/ttyACM0`, run the docker image giving access to it:

```text
sudo docker run --device=/dev/ttyACM0 -it esp32-linux
```

Give device permission to user `esp32`, change user and activate `esp-idf` inside the container:

```text
chown esp32 /dev/ttyACM0
su esp32
cd build/esp-idf
source export.sh
```

Then flash the images:

```text
cd examples/get-started/linux_boot/build
esptool.py --chip esp32 -p /dev/ttyACM0 -b 460800 --before=default_reset --after=hard_reset write_flash --flash_mode dio --flash_freq 80m --flash_size 4MB 0x1000 bootloader/bootloader.bin 0x10000 linux_boot.bin 0x8000 partition_table/partition-table.bin
cd /app/build/build-buildroot-esp32/images/
parttool.py 460800 write_partition --partition-name linux  --input xipImage
parttool.py 460800 write_partition --partition-name rootfs --input rootfs.cramfs
```

### Access Linux Shell from UART adapter

You will be able to access shell through serial monitor, you can use any application like `putty`, `minicom`, `screen`, `Arduino`...

```text
minicom -D /dev/ttyACM0 -b 115200
```

press `RST` button on ESP32 and enjoy!
