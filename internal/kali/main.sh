#!/bin/sh

perdev=`/opt/drivebadger/internal/kali/get-first-persistent-partition.sh`

if [ "$perdev" != "" ]; then
	target_partition=`basename $perdev`
	target_drive=`/opt/drivebadger/internal/generic/get-partition-drive.sh $target_partition`

	target_raw_device=`/opt/drivebadger/internal/generic/get-raw-device.sh $perdev`  # sdb3 or dm-0
	logger "persistent partition $perdev on device $target_raw_device"

	id=`/opt/drivebadger/internal/generic/get-computer-id.sh`
	target_root_directory=`/opt/drivebadger/internal/kali/get-target-directory.sh $target_partition`
	target_directory=$target_root_directory/$id
	keys_directory=`/opt/drivebadger/internal/kali/get-keys-directory.sh $target_partition`

	mkdir -p $target_directory $keys_directory
	/opt/drivebadger/internal/generic/dump-debug-files.sh $target_directory

	for uuid in `ls /dev/disk/by-uuid`; do
		tmp=`readlink /dev/disk/by-uuid/$uuid`
		current_partition=`basename $tmp`  # dm-0 is handled properly below, but dm-1 etc. not - fix before reusing this code in different context
		current_drive=`/opt/drivebadger/internal/generic/get-partition-drive.sh $current_partition`

		if [ "$current_partition" = "$target_raw_device" ] || [ "$current_partition" = "$target_partition" ]; then
			logger "skipping UUID=$uuid (partition $current_partition matches target $target_partition)"
		elif [ "$current_drive" = "$target_drive" ]; then
			logger "skipping UUID=$uuid (partition $current_partition lays on the same target drive $target_drive as target partition $target_partition)"
		else
			fs=`/opt/drivebadger/internal/generic/get-partition-fs-type.sh $current_partition $target_directory`
			drive_serial=`/opt/drivebadger/internal/generic/get-drive-serial.sh $current_drive $target_directory`

			if [ "$fs" = "swap" ]; then
				logger "skipping UUID=$uuid (swap partition $current_partition)"
			elif [ "$fs" = "apfs" ]; then
				/opt/drivebadger/internal/kali/mount/apfs.sh $target_root_directory $target_directory $keys_directory "$drive_serial" $current_partition $uuid
			elif [ "$fs" = "crypto_LUKS" ]; then
				/opt/drivebadger/internal/kali/mount/luks.sh $target_root_directory $target_directory $keys_directory "$drive_serial" $current_partition $uuid
			else
				/opt/drivebadger/internal/kali/mount/plain.sh $target_root_directory $target_directory $keys_directory "$drive_serial" $current_partition $uuid $fs
			fi
		fi
	done

	# now process encrypted drives

	for current_partition in `/opt/drivebadger/internal/generic/get-udev-unrecognized-devices.sh`; do
		current_drive=`/opt/drivebadger/internal/generic/get-partition-drive.sh $current_partition`
		drive_serial=`/opt/drivebadger/internal/generic/get-drive-serial.sh $current_drive $target_directory`

		/opt/drivebadger/internal/kali/mount/unrecognized.sh $target_root_directory $target_directory $keys_directory "$drive_serial" $current_partition
	done

	logger "finished processing drives and partitions"
fi
