package main

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"

WIN_FLAGS         :: SDL.WINDOW_SHOWN
RENDER_FLAGS      :: SDL.RENDERER_ACCELERATED
FRAMES_PER_SECOND :  f64 : 60
TARGET_DT_S       :: f64(1000) / FRAMES_PER_SECOND
WIN_WIDTH         :: 800
WIN_HEIGHT        :: 650

TILE_SIZE    :: 10

STAGE_WIDTH  :: WIN_WIDTH / TILE_SIZE
STAGE_HEIGHT :: WIN_HEIGHT / TILE_SIZE

FRAME_COUNTDOWN :: 50

int_rand : rand.Rand

neighbour_choice_ints : [4]int = {0, 1, 2, 3}

// Top    = 0
// Right  = 1
// Bottom = 2
// Left   = 3

Game :: struct
{
    renderer       : ^SDL.Renderer,
    stage          : [STAGE_WIDTH * STAGE_HEIGHT]int,
    perf_frequency : f64,
}

Vec4 :: [4]u8

Neighbour_Position :: enum{ Top, Right, Bottom, Left }

Dead       : f32 : 0.0
Bad        : f32 : 0.25
Ok         : f32 : 0.5
Well       : f32 : 0.75
Respawning : f32 : 0.9
Alive      : f32 : 1.0

Health :: enum{Dead, Bad, Ok, Well, Respawning, Alive}

Cell :: struct
{
    dest   : SDL.Rect,
    color  : Vec4,
    health : Health,
}
cells : [STAGE_WIDTH * STAGE_HEIGHT]Cell

game := Game{}

cells_len : int

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

    cells_len = len(cells)
    assert(STAGE_WIDTH * STAGE_HEIGHT <= cells_len)
    for j in 0..<STAGE_HEIGHT
    {
        for i in 0..<STAGE_WIDTH
        {
            health : Health
            if rand_bool(3)
            {
                health = Health.Alive
            }
            else
            {
                health = Health.Dead
            }
            //c := cast(u8)( cast(f32)((j * STAGE_WIDTH) + i ) / cast(f32)cells_len * 255 )
            c : u8 = 255
            cells[((j * STAGE_WIDTH) + i )] = Cell{
                SDL.Rect{
                    cast(i32)((i+1) * TILE_SIZE),
                    cast(i32)((j+1) * TILE_SIZE),
                    TILE_SIZE, TILE_SIZE,
                },
                Vec4{c, c, c, 100},
                health,
            }
        }
    }

    game.perf_frequency = f64(SDL.GetPerformanceFrequency())
    start : f64
    end   : f64

    event : SDL.Event
    state : [^]u8

    frame_render_countdown := FRAME_COUNTDOWN

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

        if frame_render_countdown == 0
        {
            move_cells()
            update_cells()
            frame_render_countdown = FRAME_COUNTDOWN
        }
        render_cells()

        SDL.RenderPresent(game.renderer)

        SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)

        SDL.RenderClear(game.renderer)

        end = get_time()
        // fmt.printf("Time: %f\n", end - start) // 0.120
        for end - start < TARGET_DT_S
        {
            end = get_time()
        }
        frame_render_countdown = frame_render_countdown - 1
    }
}

update_cells :: proc()
{
    for j in 0..<STAGE_HEIGHT
    {
        for i in 0..<STAGE_WIDTH
        {
            idx := ((j * STAGE_WIDTH) + i)

            cell := &cells[idx]

            // Skip Alive
            if cell.health == Health.Alive do continue

            rect := SDL.Rect{
                cell.dest.x,                    
                cell.dest.y,                    
                cell.dest.w,                    
                cell.dest.h,                    
            }
            has_neighbour := false
            {
                _cell, ok := get_cell_top(j, i).?
                if ok && is_alive(_cell.health) do has_neighbour = true
            }
            {
                _cell, ok := get_cell_right(j, i).?
                if ok && is_alive(_cell.health) do has_neighbour = true
            }
            {
                _cell, ok := get_cell_bottom(j, i).?
                if ok && is_alive(_cell.health) do has_neighbour = true
            }
            {
                _cell, ok := get_cell_left(j, i).?
                if ok && is_alive(_cell.health) do has_neighbour = true
            }

            if has_neighbour
            {
                cell.health = increase_health(cell.health)
            }
            else
            {
                cell.health = decrease_health(cell.health)
            }
        }
    }
}

render_cell :: proc(rect : ^SDL.Rect, color : Vec4, health : Health)
{
    c := color
    switch health
    {
        case Health.Alive:
            c = Vec4{ 55, 163, 16, 100 }
        case Health.Well:
            c = Vec4{ 26, 158, 161, 100 }
        case Health.Ok:
            c = Vec4{ 53, 49, 181, 100 }
        case Health.Bad:
            c = Vec4{ 186, 43, 174, 100 }
        case Health.Respawning:
        case Health.Dead:
            c = Vec4{ 189, 45, 57, 100 }
    }
    SDL.SetRenderDrawColor(game.renderer, c[0], c[1], c[2], c[3])
    SDL.RenderDrawRect(game.renderer, rect)
}

render_cells :: proc()
{
    for i in 0..<len(cells)
    {
        if cells[i].health == Health.Dead || cells[i].health == Health.Respawning
        {
            continue
        }
        cell := &cells[i]
        render_cell(&cell.dest, cell.color, cell.health)
    }
}

move_cell :: proc(j, i : int)
{
    if rand_bool(3) == true
    {
        // Random rance for 4 move locations
        pos := rand_neighbour_position()
        cell : ^Cell
        // Check if cell already exists there
        switch pos {
        case Neighbour_Position.Top:
            cell, ok := get_cell_top(j, i).?
            if !ok do break
        case Neighbour_Position.Right:
            cell, ok := get_cell_right(j, i).?
            if !ok do break
        case Neighbour_Position.Bottom:
            cell, ok := get_cell_bottom(j, i).?
            if !ok do break
        case Neighbour_Position.Left:
            cell, ok := get_cell_left(j, i).?
            if !ok do break
        }

        if cell != nil && cell.health == Health.Dead
        {
            _j, _i := get_cell_neighbour_coords(i, j, pos)
            // Set new position to current cell
            new_cell := copy_cell(cell)
            cell = &Cell{
                cell.dest,
                cell.color,
                Health.Dead,
            }
            // Set current cell to dead
            fmt.println("Move")
        }
    }
}

move_cells :: proc()
{
    for j in 0..<STAGE_HEIGHT
    {
        for i in 0..<STAGE_WIDTH
        {
            idx := ((j * STAGE_WIDTH) + i)
            move_cell(j, i)
        }
    }
}

increase_health :: proc(health : Health) -> Health
{
    new_health := health
    // Introduce chance of bad things happening
    if rand_bool(4) == true
    {
        return Health.Dead
    }

    if rand_bool(35) == true
    {
        switch health
        {
            case Health.Well:
                new_health = Health.Alive
            case Health.Ok:
                new_health = Health.Well
            case Health.Bad:
                new_health = Health.Ok
            case Health.Respawning:
                new_health = Health.Bad
            case Health.Dead:
                if rand_bool(5) == true do new_health = Health.Respawning
            case Health.Alive:
                break
        }
    }
    return new_health
}
decrease_health :: proc(health : Health) -> Health
{
    new_health : Health
    switch health
    {
        case Health.Alive:
            new_health = Health.Well
        case Health.Well:
            new_health = Health.Ok
        case Health.Ok:
            new_health = Health.Bad
        case Health.Bad:
        case Health.Respawning:
        case Health.Dead:
            new_health = Health.Dead
            break
    }
    return new_health
}

get_time :: proc() -> f64
{
    return f64(SDL.GetPerformanceCounter()) * 1000 / game.perf_frequency
}

collision :: proc(x1, y1, w1, h1, x2, y2, w2, h2: i32) -> bool
{
	return (max(x1, x2) < min(x1 + w1, x2 + w2)) && (max(y1, y2) < min(y1 + h1, y2 + h2))
}

// UTILITIES

get_cell_top :: proc(j, i : int) -> Maybe(^Cell)
{
    return get_cell(j - 1, i)
}
get_cell_right :: proc(j, i : int) -> Maybe(^Cell)
{
    return get_cell(j, i + 1)
}
get_cell_bottom :: proc(j, i : int) -> Maybe(^Cell)
{
    return get_cell(j + 1, i)
}
get_cell_left :: proc(j, i : int) -> Maybe(^Cell)
{
    return get_cell(j, i - 1)
}
get_cell :: proc(j, i : int) -> Maybe(^Cell)
{
    if j < 0 || j >= STAGE_HEIGHT do return nil

    if i < 0 || i >= STAGE_WIDTH do return nil

    idx := ((j * STAGE_WIDTH) + i)
    return &cells[idx]
}

get_cell_neighbour_coords :: proc(i, j : int, p : Neighbour_Position) -> (int, int)
{
    _j, _i : int
    switch p
    {
        case Neighbour_Position.Top:
            _j = j - 1
            _i = i
        case Neighbour_Position.Right:
            _j = j
            _i = i + 1
        case Neighbour_Position.Bottom:
            _j = j + 1
            _i = i
        case Neighbour_Position.Left:
        case:
            _j = j
            _i = i - 1
    }
    return _j, _i
}

rand_neighbour_position :: proc() -> Neighbour_Position
{
    p := rand.choice(neighbour_choice_ints[:])
    pos : Neighbour_Position
    switch p
    {
        case 0:
            return Neighbour_Position.Top
        case 1:
            return Neighbour_Position.Right
        case 2:
            return Neighbour_Position.Bottom
    }
    return Neighbour_Position.Left
}

rand_bool :: proc(weight : int) -> bool
{
    return cast(int)rand.float64_range(0, 100) < weight 
}

get_random_int :: proc() -> int
{
	return int(rand.uint32(&int_rand))
}

copy_cell :: proc(cell : ^Cell) -> Cell
{
    return Cell{
        SDL.Rect{},
        Vec4{cell.color[0], cell.color[1], cell.color[2], cell.color[3]},
        cell.health,
    }
}

is_alive :: proc(health : Health) -> bool
{
    return health != Health.Respawning && health != Health.Dead
}

