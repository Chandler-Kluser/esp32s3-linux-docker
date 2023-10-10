# Build the ESP32 Linux Kernel

Based on the [Max Filippov ESP32 Kernel Linux Build Scripts](https://github.com/jcmvbkbc/esp32-linux-build) and the [Antonio Docker Container](https://github.com/hpsaturn/esp32s3-linux) with a few modifications to make it work for me.

You will need:

- an operating system with [Docker Support](https://www.docker.com/); and
- [esp-idf](https://github.com/espressif/esp-idf)

## Build Instructions

```text
sudo docker build -t esp32s3-linux .
```

Build time lasts for around an hour to be completed, you will have a 20GB docker image with the binaries needed to flash the ESP32.

Identify in your computer where is the serial port to the ESP32-S3, I will suppose it will by `/dev/ttyACM0`:

```text
# give device access (ownership) to you current user
sudo chown $USER /dev/ttyACM0
```

Mount a container with the image you have just built from Dockerfile:

```text
sudo docker run -it esp32s3-linux
```

Copy the container ID (let us suppose it is `78bdc7c38626`) and copy the generated binaries to your native environment:

```text
sudo docker cp 78bdc7c38626:/app/build/build-buildroot-esp32s3/images/ .
sudo docker cp 78bdc7c38626:/app/build/esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/network_adapter.bin ./images
sudo docker cp 78bdc7c38626:/app/build/esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/bootloader/bootloader.bin ./images
sudo docker cp 78bdc7c38626:/app/build/esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/partition_table/partition_table.bin ./images
sudo docker cp 78bdc7c38626:/app/build/esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/partition_table/partition-table.bin ./images
```

You may now delete the docker image and container, you won't need it anymore (if you don't want to cross compile any application).

## Flash Inscrutions

Activate `esp-idf` environment wherever it have been installed, I will suppose it is installed in `/opt/esp-idf`:

```text
. /opt/esp-idf/export.sh
```

Then navigate to `images` folder and run:

```text
esptool.py --chip esp32s3 -p /dev/ttyACM0 -b 921600 --before=default_reset --after=hard_reset write_flash 0x0 bootloader.bin 0x10000 network_adapter.bin 0x8000 partition-table.bin
parttool.py -p /dev/ttyACM0 -b 921600 write_partition --partition-name linux  --input xipImage
parttool.py -p /dev/ttyACM0 -b 921600 write_partition --partition-name rootfs --input rootfs.cramfs
parttool.py -p /dev/ttyACM0 -b 921600 write_partition --partition-name etc --input etc.jffs2
```

You will be able to access shell through serial monitor, you can use any application like `putty`, `minicom`, `screen`, `Arduino`...

```text
minicom -D /dev/ttyACM0 -b 115200
```

press `RST` button on ESP32-S3 and enjoy!
