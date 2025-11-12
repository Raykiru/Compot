package main

import "core:fmt"
import ma "vendor:miniaudio"

main :: proc() {

	device_config := ma.device_config_init(.playback)
	device_config.playback.format = .f32
	// device_config.sampleRate = 48000

	device: ma.device

	if err := ma.device_init(nil, &device_config, &device); err != nil {
		fmt.printfln("Failed to initialize device: %v", err)
	}

	ma_context := ma.context_type{}
	if err := ma.context_init(nil, 0, nil, &ma_context); err != nil {
		fmt.printfln("failed to initialize context: %v", err)
	}

	playback_infos: [^]ma.device_info
	playbackCount: u32
	capture_info: [^]ma.device_info
	capture_count: u32

	if err := ma.context_get_devices(
		&ma_context,
		&playback_infos,
		&playbackCount,
		&capture_info,
		&capture_count,
	); err != nil {
		fmt.printfln("Failed to get device info: %v", err)
	}

	for device, i in playback_infos[:playbackCount] {
		name := device.name
		fmt.printfln("%v- name:%s\n", i, cstring(raw_data(name[:])))
	}


	// fmt.printfln("device_config: %#v;\n@ device:%#v;", device_config, device)
}
