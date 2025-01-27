package cells

import "core:fmt"
import rl "vendor:raylib"
import "core:os"
import "core:encoding/xml"
import "core:strings"

// Expected size for each cell
CELL_SIZE :: i32(20)

// This is defined separately in case SCREEN_SIZE % CELL_SIZE != 0
SCREEN_EXPECTED_SIZE :: 900

// How many cells are in grid
GRID_SIZE :: i32(SCREEN_EXPECTED_SIZE / CELL_SIZE)

// Side Window Constants
SIDE_WINDOW_WIDTH :: 250
// How much of the screen height the CMD window takes
SIDE_WINDOW_HIGHT_PERCENT :: 0.5

// Make sure all side window elements do not exceed the window height
#assert(SIDE_WINDOW_HIGHT_PERCENT < 1.0)

// Make sure it rounds to fit what we want
SCREEN_SIZE :: GRID_SIZE * CELL_SIZE

// Tells if the simulation should be paused
paused := false

// Grid toggles between two for easier caching
whichGrid := 0
// Used to swap for easier caching
grid0 : Grid = {}
// Used to swap for easier caching
grid1 : Grid = {}
activeGrid : ^Grid = &grid0

// Which state gets placed when writing with the cursor
penCell : CellState = 1

// The current Cellular Automaton
activeCA : CA = {}
activeCAName : string = "gol"
// Flag for if the state should advance one step
step := false

// How many ticks between each iteration
updateRate := 5
stepsPerTick := 1

main :: proc() {
    using rl
    SetTraceLogLevel(.ERROR)

    if !reloadAllXML() {
        exitf("Could not load Autos")
    }

    // gol := autoFromBirthSurvive("B3/S23")
    // fmt.println(gol)

    // autoFromBirthSurviveLog("B3/S23")

    // Cloned to avoid free errors later on
    activeCAName = strings.clone(activeCAName)
    // Will fault if invalid, which is OK
    activeCA = autos[activeCAName]

    // Set up grid
    fillCells(activeGrid, Cell{ 0, nil, nil })

    InitWindow(SCREEN_SIZE + SIDE_WINDOW_WIDTH, SCREEN_SIZE,"Cells")
    defer CloseWindow()

    SetTargetFPS(60)

    initUI()
    defer cleanupUI()

    tick := 0

    for !WindowShouldClose() {
        handleInput(activeGrid, activeCA)
        if (!paused && tick % updateRate == 0) || step {
            for i := 0; i < stepsPerTick; i += 1 {
                updateGrid(activeGrid, activeCA)
            }
            if step do step = false
        }
        tick += 1

        BeginDrawing()
            drawAll(activeGrid, activeCA)
        EndDrawing()
    }
}

// Draw everything
drawAll :: proc(grid:^Grid, ca:CA) {
    w := rl.GetScreenWidth()
    h := rl.GetScreenHeight()
    rl.ClearBackground(BLACK)
    for x in i32(0)..<len(grid) {
        for y in i32(0)..<len(grid[0]) {
            c := grid[x][y].color == nil ? ca.colors[grid[x][y].state] : grid[x][y].color.(Color)
            rl.DrawRectangle(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE, c)
        }
    }
    drawUI()
    drawPalette(ca)
}

// Handle general key inputs
handleInput :: proc(grid: ^Grid, ca:CA) {
    using rl

    handleUIInputs()

    mx := GetMouseX()
    my := GetMouseY()
    cx := mx / CELL_SIZE
    cy := my / CELL_SIZE
    // Place pen cell
    if IsMouseButtonDown(.LEFT) && onGrid(grid^, int(cx), int(cy)) {
        if penCell >= len(ca.colors) {
            penCell = 0
        }
        grid[cx][cy].state = penCell
        grid[cx][cy].color = ca.colors[penCell]
    }
    // Place cell state 0
    if IsMouseButtonDown(.RIGHT) && onGrid(grid^, int(cx), int(cy)) {
        grid[cx][cy].state = 0
        grid[cx][cy].color = ca.colors[0]
    }
    // Toggle pausing
    if IsKeyPressed(.EQUAL) {
        paused = !paused
    }
    // Handle skipping if stopped
    if rl.IsKeyPressed(.SPACE) || IsKeyDown(.LEFT_SHIFT) || IsKeyDown(.RIGHT_SHIFT) {
        step = true
    }

    // Keys are shifted. state 0 is on 1 to keep keys easier to click
    keys := []rl.KeyboardKey {nil, .ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX}
    for k, i in keys {
        if IsKeyPressed(k) && activeCA.states > i - 1 {
            penCell = i - 1
        }
    }
}

// Draws pen selector grid and handles the mouse click events on them
drawPalette :: proc(ca: CA) {
    // Get working dimensions
    X :: SCREEN_SIZE
    Y :: i32(f32(SCREEN_SIZE) * SIDE_WINDOW_HIGHT_PERCENT)
    W :: SIDE_WINDOW_WIDTH
    H :: i32(f32(SCREEN_SIZE) * (1 - SIDE_WINDOW_HIGHT_PERCENT))
    TILE_SIZE :: 30

    mouse := rl.GetMousePosition()

    curY := Y
    curX := X
    for color, i in ca.colors {
        // Goes off edge, so go back
        if curX + TILE_SIZE > SCREEN_SIZE + SIDE_WINDOW_WIDTH {
            curX = X
            curY += TILE_SIZE
        }
        // Check for mouse down
        if rl.CheckCollisionPointRec(mouse, {f32(curX), f32(curY), TILE_SIZE, TILE_SIZE}) && rl.IsMouseButtonPressed(.LEFT) {
            penCell = i
        }
        // Draw cell
        rl.DrawRectangle(curX, curY, TILE_SIZE, TILE_SIZE, color)
        // Draw border
        rl.DrawRectangleLines(curX, curY, TILE_SIZE, TILE_SIZE, penCell == i ? RED : WHITE)
        // Move on
        curX += TILE_SIZE
    }
}

// Helper function for exiting with a message
exitf :: proc(msg: string, args:..any) {
    if len(args) == 0 {
        fmt.printfln(msg)
    } else {
        fmt.printfln(msg, args)
    }
    os.exit(1)
}