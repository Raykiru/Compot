package main

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os/os2"
import ma "vendor:miniaudio"


init_sound :: proc(
	engine: ^ma.engine,
	sound_conf: ^ma.sound_config,
	fr, amp: f64,
	type: ma.waveform_type = .square,
	allocator := context.allocator,
) -> (
	sound: ^ma.sound,
	err: ma.result,
) {
	waveform_conf := ma.waveform_config_init(
		.f32,
		sound_conf.channelsOut,
		engine.sampleRate,
		type,
		amp,
		fr,
	)
	wave := new(ma.waveform)

	if err := ma.waveform_init(&waveform_conf, wave); err != nil {
		free(wave)
		return nil, err
	}

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

	rate := cast(u64)engine.sampleRate
	ma.sound_set_start_time_in_pcm_frames(c, 0)
	ma.sound_set_stop_time_in_pcm_frames(c, rate * 1)

	ma.sound_set_start_time_in_pcm_frames(f, rate * 1)
	ma.sound_set_stop_time_in_pcm_frames(f, rate * 2)

	ma.sound_set_start_time_in_pcm_frames(g, rate * 2)
	ma.sound_set_stop_time_in_pcm_frames(g, rate * 3)


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
