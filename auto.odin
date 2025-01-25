package cells

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:strings"

// grid[x][y]
Grid :: [GRID_SIZE][GRID_SIZE]Cell

// returns true if x and y are within the given grid
onGrid :: proc(grid:Grid,x,y:int,) -> bool {
    return x >= 0 && y >= 0 && x < len(grid) && y < len(grid[0])
}

// Specifies what counts as a neighbor for a CA
Neighborhood :: enum {
    // Ring
    Moore,
    // Big Plus
    Neuman,
    // Cardinals or small plus
    Plus,
    // Just the diagonals
    Diag,
    // The cell Diagnonally up-left, up-right, and just up. Useful for simulating 1d CA
    Hat,
    // Big X 
    BigX, 
}

NeighborhoodFromString := map[string]Neighborhood {
    "Moore" = .Moore,
    "Neuman" = .Neuman,
    "Plus" = .Plus,
    "Diag" = .Diag,
    "Hat" = .Hat,
    "BigX" = .BigX
}

// Cellular Automaton
CA :: struct {
    // What constitutes a neighbor to this CA
    neighborhood: Neighborhood,
    // The number of states within this CA
    states:int,
    // The rules for transition of the CA
    ts: CellTransitions,
    // Default colors used for each state. Can be overridden by manually overwriting cell colors
    colors:[]rl.Color
}

// The rules that govern the transitions of a CA. 
// The index in the array is the state
CellTransitions :: []struct {
    // The state this state will transition to if no rules fit
    default: CellState,
    // A list of conditions and the states those transition to
    rules: []CellTransitionRule
}

CellTransitionRule :: struct { cond: TransitionCondition, endState: CellState }

CellState :: int
/* Tells when neighbors should transition into a different state
    Format: xyz
    where x is number of state 0 neighbors
        y is the number of state 1 neighbors
        and so on and so on. Can use . for any number of neigbors
        Can add < or > before a number to specify a condition, thus <3
        Can use v for < or ^ for > because of the XML format using &lt; and &gt;
        Can also use [nnn] to specify multiple accepatable values for a cell

*/
TransitionCondition :: string

Cell :: struct {
    state: CellState,
    // If its not nil, then override the color
    color: union{rl.Color},
    // TODO: Used for some types of CA
    dir: enum {
        Up, Down, Left, Right, 
        UpLeft, UpRight, DownLeft, DownRight
    }
}

/* Gets all the neighboring cells based on the CA neigborhood */
getNeighbors :: proc(cx, cy: int, ca:CA, grid:^Grid) -> [dynamic]CellState {
    switch ca.neighborhood {
        case .Moore: {
            // Whole ring
            return {
                // Top
                getCellState(grid, cx - 1, cy - 1),
                getCellState(grid, cx + 0, cy - 1),
                getCellState(grid, cx + 1, cy - 1),
                // Same Row
                getCellState(grid, cx - 1, cy + 0),
                getCellState(grid, cx + 1, cy + 0),
                // Bot
                getCellState(grid, cx - 1, cy + 1),
                getCellState(grid, cx + 0, cy + 1),
                getCellState(grid, cx + 1, cy + 1),
            }
        }
        case .Neuman: {
            // Big Plus
            return {
                // Up
                getCellState(grid, cx + 0, cy - 2),
                getCellState(grid, cx + 0, cy - 1),
                // Left
                getCellState(grid, cx - 2, cy + 0),
                getCellState(grid, cx - 1, cy + 0),
                // Right
                getCellState(grid, cx + 1, cy + 0),
                getCellState(grid, cx + 2, cy + 0),
                // Down
                getCellState(grid, cx + 0, cy + 1),
                getCellState(grid, cx + 0, cy + 2),
            }
        }
        case .Plus: {
            // Small Plus
            return {
                // Up
                getCellState(grid, cx + 0, cy - 1),
                // Left
                getCellState(grid, cx - 1, cy + 0),
                // Right
                getCellState(grid, cx + 1, cy + 0),
                // Down
                getCellState(grid, cx + 0, cy + 1),
            }
        }
        case .Hat: {
            // Top 3
            return {
                // Top
                getCellState(grid, cx - 1, cy - 1),
                getCellState(grid, cx + 0, cy - 1),
                getCellState(grid, cx + 1, cy - 1),
            }
        }
        case .Diag: {
            //  X X
            //   C
            //  X X
            return {
                // Top
                getCellState(grid, cx - 1, cy - 1),
                getCellState(grid, cx + 1, cy - 1),
                // Bot
                getCellState(grid, cx - 1, cy + 1),
                getCellState(grid, cx + 1, cy + 1),
            }
        }
        case .BigX: {
            // X   X
            //  X X 
            //   C
            //  X X 
            // X   X
            return {
                // Up Left
                getCellState(grid, cx - 2, cy - 2),
                getCellState(grid, cx - 1, cy - 1),
                // Up Right
                getCellState(grid, cx - 2, cy + 2),
                getCellState(grid, cx - 1, cy + 1),
                // Down Left
                getCellState(grid, cx + 1, cy - 1),
                getCellState(grid, cx + 2, cy - 2),
                // Down Right
                getCellState(grid, cx + 1, cy + 1),
                getCellState(grid, cx + 2, cy + 2),
            }
        }
    }
    return nil
}

/* Tells if the condition matches with the number of counted neighbors */
ruleMatches :: proc(cond:TransitionCondition, counts:[]u8) -> bool {
    // Current index in the counts array
    ci := 0
    
    // Tells what the last condition was
    operation : enum { Eq, Gt, Lt, Ne } = .Eq
    isGroup := false
    groupMatch := false
    i := 0
    for ; i < len(cond) && ci < len(counts); i+=1 {
        // Handle number cases
        switch cond[i] {
            case '0'..='9': {
                v := cond[i] - '0'
                switch operation {
                    case .Eq: {
                        if counts[ci] != v {
                            if !isGroup do return false
                        } else if isGroup {
                            groupMatch = true
                        }
                    }
                    case .Ne: {
                        if counts[ci] == v {
                            if !isGroup do return false
                        } else if isGroup {
                            groupMatch = true
                        }
                    }
                    case .Gt:{
                        if counts[ci] <= v {
                            if !isGroup do return false
                        } else if isGroup {
                            groupMatch = true
                        }
                    }
                    case .Lt: {
                        if counts[ci] >= v {
                            if !isGroup do return false
                        } else if isGroup {
                            groupMatch = true
                        }
                    }
                }
                // Reset to be an equals condition
                operation = .Eq
                // Advance only if not in a group
                if !isGroup {
                    ci += 1
                }
            }
            case 'a'..='f': {
                // Hex characters just in case
                v := cond[i] - 'a'
                when true do unimplemented("hex matching")
                // Copy from 0-9
                // switch operation {

                // }
                // Reset to be an equals condition
                operation = .Eq
                ci += 1
            }
            // Because of xml markup, I add other ways to go gt and lt
            case '<', 'v': operation = .Lt
            case '>', '^': operation = .Gt
            case '!': operation = .Ne
            // Not important since numbers are just equality checks, but why not
            case '=': operation = .Eq
            // Match anything
            case '.': ci += 1
            case '[': {
                if isGroup {
                    exitf("Format '%s' has opening '[' when group is already open\n", cond)
                }
                // Start group
                isGroup = true
                groupMatch = false
            }
            case ']': {
                if !isGroup {
                    exitf("Recieved ']' in format '%s' without starting '['\n", cond)
                }
                isGroup = false
                if !groupMatch do return false
                ci += 1
            }
            case: {
                exitf("Invalid rule character of '%c'\n", cond[i])
            }
        }
        
    }
    if isGroup {
        exitf("Condition is '%s' has an open group\n", cond)
    }
    if i < len(cond) {
        exitf("Condition of '%s' has more to it than number of states (%d)\n", cond, len(counts))
    }
    if ci < len(counts) {
        exitf("Condition of '%s' did not consume all %d states\n", cond, len(counts))
    }
    return true
}

// Given a cell index, grid and CA, calculates the next state of a cell
nextState :: proc(cx, cy: int, ca: CA, grid:^Grid) -> CellState {
    nbs := getNeighbors(cx, cy, ca, grid)
    // Count up each neighbor
    counts := make([dynamic]u8)
    resize_dynamic_array(&counts, ca.states)
    for c in nbs {
        counts[c] += 1
    }

    ts := ca.ts[grid[cx][cy].state]
    // Check transition rules with the counts we have now
    for rule in ts.rules {
        // Check if you need to do that transition
        if ruleMatches(rule.cond, counts[:]) {
            return rule.endState
        }
    }

    return ts.default
}

// Gets a new cell with its next state given the CA and
nextCell :: proc(cx, cy: int, ca:CA, grid:^Grid) -> Cell {
    s := nextState(cx, cy, ca, grid)
    return Cell{s, nil, nil}
}

changeAuto :: proc(naName: string) -> bool {
    if naName not_in autos {
        return false
    }
    newAuto := autos[naName]
    // Reset colors
    for x in 0..<len(activeGrid) {
        for y in 0..<len(activeGrid[0]) {
            if activeGrid[x][y].state >= newAuto.states {
                setCellState(x, y, activeGrid, 0)
            }
            activeGrid[x][y].color = nil
        }
    }
    delete(activeCAName)
    activeCAName = strings.clone(naName)
    activeCA = newAuto
    return true
}

// TODO: B###/S### 
autoFromBirthSurvive :: proc(bs : string) -> ^CA {
    curState : enum {B, Slash, S} = nil
    bList, sList : [8]u8
    bIndex, sIndex := 0, 0
    for c in transmute([]u8)(bs) {
        switch c {
            case 'B': {
                if curState == nil {
                    curState = .B
                } else {
                    exitf("Recieved 'B' in middle of format\n")
                }
            }
            case '/': {
                if curState == .B {
                    curState = .Slash
                } else {
                    exitf("Recied '/' not after 'B' state\n")
                }
            }
            case 'S': {
                if curState == .Slash {
                    curState = .S
                } else {
                    exitf("Expected 'S' to follow after '/'\n")
                }
            }
            case '0'..='7': {
                if curState == .B {
                    bList[bIndex] = c
                    bIndex += 1
                    fmt.printf("B[%d] = %c\n", bIndex - 1, c)
                } else if curState == .S {
                    // .S
                    sList[sIndex] = c
                    sIndex += 1
                    fmt.printf("S[%d] = %c\n", sIndex - 1, c)

                } else if curState == nil || curState == .Slash {
                    fmt.println(curState)
                    exitf("Recieved '%c' at beginning or after slash\n", c)
                }
                
            }
            case: {
                exitf("B/S format invalid character '%c'\n", c)
            }
        }
    }

    
    bString := fmt.aprintf(".[%s]", bList[0:bIndex])
    sString := fmt.aprintf(".[%s]", sList[0:sIndex])
    fmt.printf("\n------------\nB = %s\nS = %s\n-------------\n", bString, sString)
    
    x := new(CA)
    x.neighborhood = .Moore
    x.states = 2
    x.ts = {
        {0, {{bString, 1}}},
        {0, {{sString, 1}}}
    }
    x.colors = {BLACK, WHITE}
    return x

    // return new_clone((CA){
        // neighborhood = .Moore, states = 2,
        // ts = {
            // 0: Dead
            // {default = 0, rules = {
                // {cond = bString, endState = 1}}
            // },
            // 1: Alive
            // {0, {
                // {sString, 1}}
            // }
        // },
        // colors = {BLACK, WHITE}
//     })
}

// B###/S### TODO
autoFromBirthSurviveLog :: proc(bs : string) {
    curState : enum {B, Slash, S} = nil
    bList, sList : [8]u8
    bIndex, sIndex := 0, 0
    for c in transmute([]u8)(bs) {
        switch c {
            case 'B': {
                if curState == nil {
                    curState = .B
                } else {
                    exitf("Recieved 'B' in middle of format\n")
                }
            }
            case '/': {
                if curState == .B {
                    curState = .Slash
                } else {
                    exitf("Recied '/' not after 'B' state\n")
                }
            }
            case 'S': {
                if curState == .Slash {
                    curState = .S
                } else {
                    exitf("Expected 'S' to follow after '/'\n")
                }
            }
            case '0'..='7': {
                if curState == .B {
                    bList[bIndex] = c
                    bIndex += 1
                    fmt.printf("B[%d] = %c\n", bIndex - 1, c)
                } else if curState == .S {
                    // .S
                    sList[sIndex] = c
                    sIndex += 1
                    fmt.printf("S[%d] = %c\n", sIndex - 1, c)

                } else if curState == nil || curState == .Slash {
                    fmt.println(curState)
                    exitf("Recieved '%c' at beginning or after slash\n", c)
                }
                
            }
            case: {
                exitf("B/S format invalid character '%c'\n", c)
            }
        }
    }

    
    bString := fmt.aprintf(".[%s]", bList[0:bIndex])
    sString := fmt.aprintf(".[%s]", sList[0:sIndex])

    fmt.printf(
`{{
    .Moore, 2,
    {{
        {{0, {{{{"%s", 1}}},
        {{0, {{{{"%s", 1}}}
    }
}
`, bString, sString)
    // return new_clone((CA){
        // neighborhood = .Moore, states = 2,
        // ts = {
            // 0: Dead
            // {default = 0, rules = {
                // {cond = bString, endState = 1}}
            // },
            // 1: Alive
            // {0, {
                // {sString, 1}}
            // }
        // },
        // colors = {BLACK, WHITE}
//     })
}