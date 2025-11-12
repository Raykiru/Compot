package main

import "base:runtime"
import "core:fmt"
import "core:os/os2"
import ma "vendor:miniaudio"

data_callback :: proc "c" (dev: ^ma.device, output: rawptr, input: rawptr, frame_c: u32) {
	wave := cast(^ma.waveform)dev.pUserData

	assert_contextless(wave != nil)

	if err := ma.waveform_read_pcm_frames(wave, output, u64(frame_c), nil); err != nil {
		context = runtime.default_context()
		fmt.println(err)
	}
}

main :: proc() {


	device_config := ma.device_config_init(.playback)

	sine_wave: ma.waveform
	device_config.playback.format = .f32
	device_config.playback.channels = 2
	device_config.sampleRate = 48000
	device_config.dataCallback = data_callback
	device_config.pUserData = &sine_wave

	device: ma.device
	defer ma.device_uninit(&device)

	if err := ma.device_init(nil, &device_config, &device); err != nil {
		fmt.panicf("Failed to initialize device: %v", err)
	}

	fmt.printfln("Device name: %s", device.playback.name)

	fmt.printfln("initializing waveform conf:")
	sine_wave_conf := ma.waveform_config_init(
		device.playback.playback_format,
		device.playback.channels,
		device.sampleRate,
		ma.waveform_type.sine,
		0.2,
		220,
	)

	fmt.printfln("initializing waveform:")
	if err := ma.waveform_init(&sine_wave_conf, &sine_wave); err != nil {
		fmt.panicf("Err initializing waveform: %v", err)
	}

	fmt.printfln("Starting device:")
	if err := ma.device_start(&device); err != nil {
		fmt.panicf("Failed to start playback device: %v", err)
	}

	p: [2]u8
	fmt.printfln("Waiting for input:")
	os2.read(os2.stdin, p[:])
	fmt.printfln("Over")
}
