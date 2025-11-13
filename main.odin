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

init_sound :: proc(
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

		return
	}

	return nil, err
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
	engine_conf := ma.engine_config_init()
	engine_conf.noAutoStart = true

	engine: ma.engine
	defer ma.engine_uninit(&engine)
	if err := ma.engine_init(&engine_conf, &engine); err != nil {
		fmt.println("Failed to init engine:", err)
		return
	}

	original_callback = cast(data_callback_t)engine.pDevice.onData
	fmt.println(engine.pDevice.playback.playback_format)


	sound_conf: ma.sound_config = ma.sound_config_init_2(&engine)

	c, _ := init_sound(&engine, &sound_conf, 261.63, 0.1)

	f, _ := init_sound(&engine, &sound_conf, 349.23, 0.1)

	g, _ := init_sound(&engine, &sound_conf, 392, 0.1)

	ma.sound_set_start_time_in_pcm_frames(c, 0)
	ma.sound_set_stop_time_in_pcm_frames(c, auto_cast engine.sampleRate * 1)

	ma.sound_set_start_time_in_pcm_frames(f, auto_cast engine.sampleRate * 1)
	ma.sound_set_stop_time_in_pcm_frames(f, auto_cast engine.sampleRate * 2)

	ma.sound_set_start_time_in_pcm_frames(g, auto_cast engine.sampleRate * 2)
	ma.sound_set_stop_time_in_pcm_frames(g, auto_cast engine.sampleRate * 3)


	// ma.sound_set_

	{ 	// engine runtime
		fmt.println("Press enter start")
		libc.getchar()
		ma.sound_start(c)
		ma.sound_start(f)
		ma.sound_start(g)


		if err := ma.engine_start(&engine); err != nil {
			fmt.println("Failed to start engine:", err)
			return
		}
		fmt.println("Engine started")


		fmt.println("Press enter to end")
		libc.getchar()
	}
}
counter: int
frames: u32
dir: int
swap: bool

data_callback_t :: #type proc "c" (dev: ^ma.device, output: rawptr, input: rawptr, frame_c: u32)
original_callback: data_callback_t
data_callback :: proc "c" (dev: ^ma.device, output: rawptr, input: rawptr, frame_c: u32) {
	context = runtime.default_context()


	// fmt.println(dev, frame_c)
	if original_callback == nil {
		os2.exit(1)
	}

	original_callback(dev, output, input, frame_c)
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
