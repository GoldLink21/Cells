package cells

// Replace all cells with the given cell
fillCells :: proc(grid:^Grid, cell:Cell) {
    for x in 0..<len(grid) {
        for y in 0..<len(grid[0]) {
            grid[x][y] = cell
        }
    }
}

// Set a cell at a position to a new cell
setCell :: proc(x, y: int, grid:^Grid, cell:Cell) {
    grid[x][y] = cell
}

// Shortcut for updating a single cell's state and its color
setCellState :: proc(x, y: int, grid:^Grid, state:CellState) {
    grid[x][y].state = state
    // grid[x][y].color = activeCA.colors[state]
    grid[x][y].color = nil
}

// Get the cell at a position
getCell :: proc(grid:^Grid, x, y:int) -> ^Cell {
    w := len(grid)
    h := len(grid[0])
    // Simple wrapping that does not work if it gets too far negative
    rx := (x + w) % w
    ry := (y + h) % h
    // For full wrapping, could use this, but its slower
    // rx := ((x % w) + w) % w
    // ry := ((y % h) + h) % h
    return &grid[rx][ry]
}

// Get the cell state at a position
getCellState :: proc(grid:^Grid, x, y:int) -> CellState {
    return getCell(grid, x, y).state
}

// Runs through the grid and generates its next state, then updates the activeGrid
updateGrid :: proc(grid:^Grid, ca:CA) {
    for x in 0..<len(grid) {
        for y in 0..<len(grid[0]) {
            if whichGrid == 0 {
                // grid1 is the next one to load
                grid1[x][y] = nextCell(x, y, ca, grid)
            } else {
                // grid0 is the one to load
                grid0[x][y] = nextCell(x, y, ca, grid)
            }
        }
    }
    // Swap grids
    if whichGrid == 0 {
        activeGrid = &grid1
    } else {
        activeGrid = &grid0
    }
    // Swap the grid that is active
    whichGrid = 1 - whichGrid
}