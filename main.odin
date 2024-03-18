package main

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"

WIN_FLAGS :: SDL.WINDOW_SHOWN
RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
FRAMES_PER_SECOND : f64 : 60
TARGET_DT_S :: f64(1000) / FRAMES_PER_SECOND
WIN_WIDTH :: 1600
WIN_HEIGHT :: 960
SHOW_HITBOXES :: false

int_rand : rand.Rand


Game :: struct
{
    renderer       : ^SDL.Renderer,
    perf_frequency : f64,
}

Cell :: struct
{
    dest : SDL.Rect,
}
cells : [100]Cell

game := Game{}

main :: proc()
{
	assert(SDL.Init(SDL.INIT_VIDEO) == 0, SDL.GetErrorString())
	assert(SDL_Image.Init(SDL_Image.INIT_PNG) != nil, SDL.GetErrorString())
	defer SDL.Quit()

	window := SDL.CreateWindow(
		"Odin Cells",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		WIN_WIDTH,
		WIN_HEIGHT,
		WIN_FLAGS,
	)
	assert(window != nil, SDL.GetErrorString())
	defer SDL.DestroyWindow(window)

	// Must not do VSync because we run the tick loop on the same thread as rendering.
	game.renderer = SDL.CreateRenderer(window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	defer SDL.DestroyRenderer(game.renderer)

	SDL.RenderSetLogicalSize(game.renderer, WIN_WIDTH, WIN_HEIGHT)


    for i in 0..<100
    {
        cells[i] = Cell{
            SDL.Rect{
                cast(i32)rand.float64_range(0, WIN_WIDTH),
                cast(i32)rand.float64_range(0, WIN_HEIGHT),
                5,
                5,
            },
        }
    }


    game.perf_frequency = f64(SDL.GetPerformanceFrequency())
    start : f64
    end   : f64

    event : SDL.Event
    state : [^]u8

    game_loop : for
    {
        start = get_time()

        state = SDL.GetKeyboardState(nil)

        if SDL.PollEvent(&event)
        {
            if event.type == SDL.EventType.QUIT
            {
                break game_loop
            }
        }


        for i in 0..<len(cells)
        {
            render_hitbox(&cells[i].dest)
        }


        end = get_time()
        for end - start < TARGET_DT_S
        {
            end = get_time()
        }


        SDL.RenderPresent(game.renderer)

        SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)

        SDL.RenderClear(game.renderer)
    }
}

render_hitbox :: proc(dest: ^SDL.Rect)
{
	r := SDL.Rect{ dest.x, dest.y, dest.w, dest.h }

	SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 100)
	SDL.RenderDrawRect(game.renderer, &r)
}

get_time :: proc() -> f64
{
    return f64(SDL.GetPerformanceCounter()) * 1000 / game.perf_frequency
}

collision :: proc(x1, y1, w1, h1, x2, y2, w2, h2: i32) -> bool
{
	return (max(x1, x2) < min(x1 + w1, x2 + w2)) && (max(y1, y2) < min(y1 + h1, y2 + h2))
}

get_random_int :: proc() -> int
{
	return int(rand.uint32(&int_rand))
}

