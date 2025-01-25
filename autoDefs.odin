package cells
import rl"vendor:raylib"
import "core:os"
import "core:encoding/xml"
import "core:fmt"
import "core:strconv"
import "core:strings"

// Color Shortcuts
Color  :: rl.Color
WHITE  :: rl.WHITE
BLACK  :: rl.BLACK
BLUE   :: rl.BLUE
YELLOW :: rl.YELLOW
RED    :: rl.RED
GREEN  :: rl.GREEN

readAutosXML :: proc() -> (succ:bool) {
    bytes, ok := os.read_entire_file_from_filename("autos.xml")
    if !ok {
        fmt.printfln("Could not open autos.xml")
        return false
    }
    defer delete(bytes)
    doc, err := xml.parse_bytes(bytes)
    if err != nil {
        fmt.printfln("Could not parse autos.xml as XML")
        return false
    }
    defer xml.destroy(doc)
    // fmt.println(doc.elements[0])
    // auto_id, found := xml.find_child_by_ident(doc, 0, "autos") 
    // if !found {
    //     fmt.printfln("Could not find root autos element")
    //     return false
    // }
    // auto := doc.elements[auto_id]
    auto := doc.elements[0]

    newAutos := make(map[string]CA)
    
    // Create new autos

    // <auto name="name" neighborhood="Moore">
    for autoId in auto.value {
        id := autoId.(xml.Element_ID)
        newAuto : CA
        name := ""
        // Check attributes
        for attr in doc.elements[id].attribs {
            if attr.key == "name" {
                name = strings.clone(attr.val)
            }
            if attr.key == "neighborhood" {
                newAuto.neighborhood = NeighborhoodFromString[attr.val]
            }
        }
        // Verify name and neighborhood
        // if name == "" || newAuto.neighborhood == nil {
        //     fmt.printfln("Invalid auto def: %s %s", name, newAuto.neighborhood)
        //     return false
        // }
        // Set up newAuto
        newAuto.states  = len(doc.elements[id].value)
        newAuto.colors  = make([]rl.Color, newAuto.states)
        newAuto.ts      = make(CellTransitions, newAuto.states)
        // Resolve states
        // <state name="name" color="XXXXXX" default="#">
        for i := 0; i < newAuto.states; i += 1 {
            stateId := doc.elements[id].value[i].(xml.Element_ID)
            state := doc.elements[stateId]
            
            newAuto.ts[i].rules = make([]CellTransitionRule,len(state.value))

            // Resolve state attributes
            for attr in state.attribs {
                // Ignore name key
                if attr.key == "color" {
                    // TODO:
                    nv, ok := strconv.parse_i64_of_base(
                        fmt.tprintf("%sFF", attr.val), 16
                    )
                    if !ok {
                        fmt.printfln("Invalid color number")
                        return false
                    }
                    newAuto.colors[i] = rl.GetColor(u32(nv))
                }
                if attr.key == "default" {
                    // TODO:
                    def, ok := strconv.parse_int(attr.val)
                    if !ok || def >= newAuto.states {
                        fmt.printfln("Invalid default number")
                        return false
                    }
                    newAuto.ts[i].default = def
                }
            }
            // Iterate transitions
            // <ts to="#">..</ts>
            for tsElem, j in state.value {
                tsId := tsElem.(xml.Element_ID)
                ts := doc.elements[tsId]
                toVal, ok := strconv.parse_int(ts.attribs[0].val)
                if !ok {
                    fmt.printfln("Invalid to number")
                    return false
                }
                newAuto.ts[i].rules[j] = {
                    cond = strings.clone(ts.value[0].(string)),
                    endState = toVal
                }
            }
        }
        newAutos[name] = newAuto
        // fmt.println(newAuto)
    }

    // Cleanup existing autos only if success
    for k in autos {
        dk, dv := delete_key(&autos, k)
        delete(dk)
        for ts in dv.ts {
            for rule in ts.rules do delete(rule.cond)
            delete(ts.rules)
        }
        delete(dv.ts)
        delete(dv.colors)
    }
    delete_map(autos)
    autos = newAutos
    
    // fmt.println(autos)
    return true
}

GOL_AUTO := CA{
    neighborhood = .Moore, 
    states = 2,
    // 0: Dead
    ts = {{0, {{".3",1}}},
    // 1: Alive
        {0, {{".[23]", 1}}}},
    colors = {BLACK, WHITE}
}

// Gets Loaded from autos.xml
autos := map[string]CA {
    // "gol" = {
    //     neighborhood = .Moore, 
    //     states = 2,
    //     // 0: Dead
    //     ts = {{0, {{".3",1}}},
    //     // 1: Alive
    //         {0, {{".[23]", 1}}}},
    //     colors = {BLACK, WHITE}
    // },
    // "gol_neuman" = {
    //     .Neuman, 2,
    //     // 0: Dead
    //     {{0, {{".3",1}}},
    //     // 1: Alive
    //      {0, {{".[23]", 1}}}},
    //     {BLACK, WHITE}
    // },
    // "gol_big_x" = {
    //     .BigX, 2,
    //     // 0: Dead
    //     {{0, { {".3",1} }},
    //     // 1: Alive
    //      {0, { {".2", 1},
    //            {".3", 1} }}},
    //     {BLACK, WHITE}
    // },
    // "wireworld" = {
    //     .Moore, 4,
    //     {   // 0: Nothing
    //         {0, {}},
    //         // 1: Electron Head -> Electron Tail
    //         {2, {}},
    //         // 2: Electron Tail -> Conduit
    //         {3, {}},
    //         // 3: Conduit -[12 Heads]-> Head
    //         {3, {
    //             {".[12]..", 1},
    //             // {".2..", 1}
    //         }}
    //     },
    //     {BLACK, BLUE, RED, YELLOW}
    // },
    // "brians_brain" = {
    //     .Moore, 3,
    //     {   // 0: Dead -[2 Alive]-> Alive 
    //         {0, { {".2.", 1} }},
    //         // 1: Alive -> Dying
    //         {2, {}},
    //         // 2: Dying -> Dead
    //         {0, {}}
    //     },
    //     {BLACK, WHITE, BLUE}
    // },
    // "day_and_night" = {
    //     .Moore, 2,
    //     {   // 0: Dead -[3,6,7,8]-> Alive
    //         {0, {{".[368]", 1}}},
    //         // 1: Alive -[3,4,6,7,8]->Alive
    //         {1, {{".[0125]", 0}}}
    //     },
    //     {BLACK, YELLOW}
    // },
    // "seeds" = {
    //     .Moore, 2,
    //     {
    //         // 0: Dead -[2]-> Alive
    //         {0,{{".2",1}}},
    //         // 1: Alive -> Dead
    //         {0,{}}
    //     },
    //     {BLACK,GREEN}
    // },
    // "gol_and_d" = {
    //     neighborhood = .Moore, 
    //     states = 3,
    //     ts = {
    //         // 0: Dead
    //         {0, {{".3.",1}}},
    //         // 1: Alive
    //         {1, {
    //             // {".[23].", 1},
    //             {".[0145678].", 2}
    //         }},
    //         // 2: Dying
    //         {0, {}}
    //     },
    //     colors = {BLACK, WHITE, BLUE}
    // },
    // "soldier" = {
    //     .Moore, 5,
    //     {
    //         // 0: Nothing
    //         {0, {
    //             // More RED so become RED
    //             {".20..",1},
    //             // More BLUE so become BLUE
    //             {".02..",2},
    //         }},
    //         // 1: RED
    //         {0, {
    //             // Dies unless there is <5 empty space
    //             {"<5....", 3}
    //         }},
    //         // 2: BLUE
    //         {0, {
    //             {"<5....", 3}
    //         }},
    //         // 3: Dying
    //         {3, {
    //             {"...4.",0},
    //             //{"...8.",4}
    //         }},
    //         // 4: Wall
    //         {4,{}}
    //     },
    //     {BLACK, RED, BLUE, rl.GRAY, WHITE}
    // },
    // "path" = {
    //     .Moore, 4,
    //     {
    //         // 0: Nothing
    //         {0, {
    //             // Dead with a center => Border
    //             {".>00.", 2}, 
    //             // Dead with a border => Edge
    //             {"..>0.", 3}
    //         }},
    //         // 1: Path Center
    //         {1, {}},
    //         // 2: Path Edge
    //         {2, {
    //             // Kill if it has no Center
    //             {".0..", 0}
    //         }},
    //         // 3: Path outer wall
    //         {3, {
    //             // If next to any Center, becomes an inner segment
    //             {".>0..", 2},
    //             // If has no Edges, kill
    //             {"..0.", 0}
    //         }}
    //     },
    //     {GREEN, rl.Color{122, 39, 0, 255}, rl.BROWN, rl.GRAY}
    // }
}

