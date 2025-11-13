package main

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os/os2"
import ma "vendor:miniaudio"

waveform :: proc(
	fr, amp: f64,
	allocator := context.allocator,
) -> (
	wave: ^ma.waveform,
	err: ma.result,
) {
	waveform_conf := ma.waveform_config_init(.f32, 2, 48000, .square, amp, fr)
	wave = new(ma.waveform)

	if err := ma.waveform_init(&waveform_conf, wave); err != nil {
		free(wave)
		return nil, err
	}

	return
}


stop_sound :: proc(sound: ^ma.sound, err: ma.result) {
	if err != nil {
		ma.sound_stop(sound)
		ma.sound_uninit(sound)
	}
}

@(deferred_out = stop_sound)
play_sound :: proc(
	engine: ^ma.engine,
	sound_conf: ^ma.sound_config,
	fr, amp: f64,
	allocator := context.allocator,
) -> (
	sound: ^ma.sound,
	err: ma.result,
) {

	if wave, err := waveform(fr, amp); err == nil {
		sound = new(ma.sound)

		if err := ma.sound_init_from_data_source(
			engine,
			cast(^ma.data_source)wave,
			sound_conf.flags,
			nil,
			sound,
		); err != nil {
			fmt.println("Failed to init sound:", err)
			ma.sound_uninit(sound)
			free(sound)

			return nil, err
		}

		if err := ma.sound_start(sound); err != nil {
			fmt.println("Failed to start sound")
			ma.sound_uninit(sound)
			fmt.println("Engine started")
			return nil, err
		}
		return
	}

	return nil, err
}

main :: proc() {

	engine: ma.engine
	defer ma.engine_uninit(&engine)
	if err := ma.engine_init(nil, &engine); err != nil {
		fmt.println("Failed to init engine:", err)
		return
	}
	ma.engine_stop(&engine)


	sound_conf: ma.sound_config = ma.sound_config_init_2(&engine)

	c, _ := play_sound(&engine, &sound_conf, 261.63, 0.1)

	f, _ := play_sound(&engine, &sound_conf, 349.23, 0.1)

	g, _ := play_sound(&engine, &sound_conf, 392, 0.1)


	fmt.println("Press enter start")
	libc.getchar()


	fmt.println("Engine started")
	if err := ma.engine_start(&engine); err != nil {
		fmt.println("Failed to start engine:", err)
		return
	}


	fmt.println("Press enter to end")
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
