package main

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"

WIN_FLAGS         :: SDL.WINDOW_SHOWN
RENDER_FLAGS      :: SDL.RENDERER_ACCELERATED
FRAMES_PER_SECOND : f64 : 60
TARGET_DT_S       :: f64(1000) / FRAMES_PER_SECOND
WIN_WIDTH         :: 800
WIN_HEIGHT        :: 650
SHOW_HITBOXES     :: false

TILE_SIZE    :: 10

STAGE_WIDTH  :: WIN_WIDTH / TILE_SIZE
STAGE_HEIGHT :: WIN_HEIGHT / TILE_SIZE

int_rand : rand.Rand

Game :: struct
{
    renderer       : ^SDL.Renderer,
    stage          : [STAGE_WIDTH * STAGE_HEIGHT]int,
    perf_frequency : f64,
}

Vec4 :: [4]u8

Cell :: struct
{
    dest   : SDL.Rect,
    color  : Vec4,
    health : int,
    alive  : bool,
}
cells : [STAGE_WIDTH * STAGE_HEIGHT]Cell

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


    /*
    01234
    56789
    */

    // Total tiles: 5200
    cell_count := cast(f32)len(cells)
    for j in 0..<STAGE_HEIGHT
    {
        for i in 0..<STAGE_WIDTH
        {
            c := cast(u8)( cast(f32)((j * STAGE_WIDTH) + i ) / cell_count * 255 )
            cells[((j * STAGE_WIDTH) + i )] = Cell{
                SDL.Rect{
                    cast(i32)((i+1) * TILE_SIZE),
                    cast(i32)((j+1) * TILE_SIZE),
                    TILE_SIZE, TILE_SIZE,
                },
                Vec4{c, c, c, 100},
                3, true,
            }
        }
    }

    // cast(i32)rand.float64_range(0, WIN_WIDTH),

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


        //for i in 0..<len(cells)
        //{
        //    render_hitbox(&cells[i].dest)
        //}

        update_cells()
        render_cells()


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

update_cells :: proc()
{
    for i in 0..<len(cells)
    {
        // @todo(moosch): implement rules
        
    }
}

render_cells ::proc()
{
    for j in 0..<STAGE_HEIGHT
    {
        for i in 0..<STAGE_WIDTH
        {
            dest := &cells[((j * STAGE_WIDTH) + i )].dest
            c := cells[((j * STAGE_WIDTH) + i )].color
            r := SDL.Rect{
                dest.x,
                dest.y,
                dest.w,
                dest.h,
            }
            SDL.SetRenderDrawColor(game.renderer, c[0], c[1], c[2], 100)
            SDL.RenderDrawRect(game.renderer, &r)
        }
    }
    /* for i in 0..<len(cells)
    {
        if cells[i].alive == true
        {
            dest := &cells[i].dest
            r := SDL.Rect{
                dest.x,
                dest.y,
                dest.w,
                dest.h,
            }
            SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 100)
            SDL.RenderDrawRect(game.renderer, &r)

            /* {
                r := SDL.Rect{
                    dest.x + 5,
                    dest.y + 5,
                    dest.w,
                    dest.h,
                }
                SDL.SetRenderDrawColor(game.renderer, 255, 0, 0, 100)
                SDL.RenderDrawRect(game.renderer, &r)
            } */
        }
    } */
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

