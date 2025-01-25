package cells
import rl"vendor:raylib"

// Color Shortcuts
Color  :: rl.Color
WHITE  :: rl.WHITE
BLACK  :: rl.BLACK
BLUE   :: rl.BLUE
YELLOW :: rl.YELLOW
RED    :: rl.RED
GREEN  :: rl.GREEN

autos := map[string]CA {
    "gol" = {
        neighborhood = .Moore, 
        states = 2,
        // 0: Dead
        ts = {{0, {{".3",1}}},
        // 1: Alive
            {0, {{".[23]", 1}}}},
        colors = {BLACK, WHITE}
    },
    "gol_neuman" = {
        .Neuman, 2,
        // 0: Dead
        {{0, {{".3",1}}},
        // 1: Alive
         {0, {{".[23]", 1}}}},
        {BLACK, WHITE}
    },
    "gol_big_x" = {
        .BigX, 2,
        // 0: Dead
        {{0, { {".3",1} }},
        // 1: Alive
         {0, { {".2", 1},
               {".3", 1} }}},
        {BLACK, WHITE}
    },
    "wireworld" = {
        .Moore, 4,
        {   // 0: Nothing
            {0, {}},
            // 1: Electron Head -> Electron Tail
            {2, {}},
            // 2: Electron Tail -> Conduit
            {3, {}},
            // 3: Conduit -[12 Heads]-> Head
            {3, {
                {".[12]..", 1},
                // {".2..", 1}
            }}
        },
        {BLACK, BLUE, RED, YELLOW}
    },
    "brians_brain" = {
        .Moore, 3,
        {   // 0: Dead -[2 Alive]-> Alive 
            {0, { {".2.", 1} }},
            // 1: Alive -> Dying
            {2, {}},
            // 2: Dying -> Dead
            {0, {}}
        },
        {BLACK, WHITE, BLUE}
    },
    "day_and_night" = {
        .Moore, 2,
        {   // 0: Dead -[3,6,7,8]-> Alive
            {0, {{".[368]", 1}}},
            // 1: Alive -[3,4,6,7,8]->Alive
            {1, {{".[0125]", 0}}}
        },
        {BLACK, YELLOW}
    },
    "seeds" = {
        .Moore, 2,
        {
            // 0: Dead -[2]-> Alive
            {0,{{".2",1}}},
            // 1: Alive -> Dead
            {0,{}}
        },
        {BLACK,GREEN}
    },
    "gol_and_d" = {
        neighborhood = .Moore, 
        states = 3,
        ts = {
            // 0: Dead
            {0, {{".3.",1}}},
            // 1: Alive
            {1, {
                // {".[23].", 1},
                {".[0145678].", 2}
            }},
            // 2: Dying
            {0, {}}
        },
        colors = {BLACK, WHITE, BLUE}
    },
    "soldier" = {
        .Moore, 5,
        {
            // 0: Nothing
            {0, {
                // More RED so become RED
                {".20..",1},
                // More BLUE so become BLUE
                {".02..",2},
            }},
            // 1: RED
            {0, {
                // Dies unless there is <5 empty space
                {"<5....", 3}
            }},
            // 2: BLUE
            {0, {
                {"<5....", 3}
            }},
            // 3: Dying
            {3, {
                {"...4.",0},
                //{"...8.",4}
            }},
            // 4: Wall
            {4,{}}
        },
        {BLACK, RED, BLUE, rl.GRAY, WHITE}
    },
    "path" = {
        .Moore, 4,
        {
            // 0: Nothing
            {0, {
                // Dead with a center => Border
                {".>00.", 2}, 
                // Dead with a border => Edge
                {"..>0.", 3}
            }},
            // 1: Path Center
            {1, {}},
            // 2: Path Edge
            {2, {
                // Kill if it has no Center
                {".0..", 0}
            }},
            // 3: Path outer wall
            {3, {
                // If next to any Center, becomes an inner segment
                {".>0..", 2},
                // If has no Edges, kill
                {"..0.", 0}
            }}
        },
        {GREEN, rl.Color{122, 39, 0, 255}, rl.BROWN, rl.GRAY}
    }
}

