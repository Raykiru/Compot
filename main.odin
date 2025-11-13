package main

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os/os2"
import ma "vendor:miniaudio"


main :: proc() {
	engine_conf: ma.engine_config = ma.engine_config_init()

	engine: ma.engine
	if err := ma.engine_init(&engine_conf, &engine); err != nil {
		fmt.println("Failed to init engine:", err)
		return
	}
	if err := ma.engine_start(&engine); err != nil {
		fmt.println("Failed to start engine:", err)
	}
	fmt.println("Engine started")
	libc.getchar()

}
counter: int
frames: u32
dir: int
swap: bool

data_callback :: proc "c" (dev: ^ma.device, output: rawptr, input: rawptr, frame_c: u32) {
	context = runtime.default_context()
	waves := cast([^]ma.waveform)dev.pUserData
	wave1 := &waves[0]
	wave2 := &waves[1]

	// assert_contextless(wave1 != nil)
	notes := [?]f64{261.63, 261.63, 293.66, 329.63, 349.23, 392, 440, 493.88, 523.25, 523.25}

	if frames % 48000 == 0 {
		ma.waveform_set_frequency(wave1, notes[counter])
		ma.waveform_set_type(wave1, ma.waveform_type.square)
		ma.waveform_set_amplitude(wave1, 0.01)
		if counter == 0 do dir = 1
		if counter == len(notes) - 1 do dir = -1

		fmt.printfln("{1:v} wave: {0:#v}", wave1.config.frequency, counter)
		counter += dir
	}

	// swap = !swap
	swap = true
	if err := ma.waveform_read_pcm_frames(wave1, output, u64(frame_c), nil); err != nil {
		fmt.println(err)
	}

	if err := ma.waveform_read_pcm_frames(wave2, output, u64(frame_c), nil); err != nil {
		fmt.println(err)
	}
	frames += frame_c
}


play_wave :: proc() {
	sine_waves: [^]ma.waveform = make([^]ma.waveform, 2)

	device_config := ma.device_config_init(.playback)

	device_config.playback.format = .f32
	device_config.playback.channels = 2
	device_config.sampleRate = 48000
	device_config.dataCallback = data_callback
	device_config.pUserData = sine_waves

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
		440,
	)

	fmt.printfln("initializing waveform:")
	if err := ma.waveform_init(&sine_wave_conf, &sine_waves[0]); err != nil {
		fmt.panicf("Err initializing waveform: %v", err)
	}

	if err := ma.waveform_init(&sine_wave_conf, &sine_waves[1]); err != nil {
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
