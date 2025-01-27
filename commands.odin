package cells

import "core:strings"
import "core:fmt"
import "core:strconv"
import "core:math/rand"
import "core:slice"

COMMANDS :: [][2]string{
    {"place <count> <type>", ""},
    {"clear",                ""},
    {"auto <name>",          ""},
    {"rate <rate>",          ""},
    {"reload",               ""},
    {"steps <rate>",         ""},
    {"scatter <amount>",     ""},
    {"test <auto>",          ""},
    {"probe <auto>",         ""},
}

// Parses and runs a command
runCommand :: proc(input: string) -> union{string} {
    input := strings.trim(input, " \t\n")
    if len(input) == 0 do return nil
    if len(input) != 0 {
        args := strings.fields(input)
        defer delete(args)
        switch args[0] {
            case "place", "p": {
                argCount(len(args), 2, "place") or_return
                val := intArg(args[1], "place count", 0, int(GRID_SIZE * GRID_SIZE)) or_return
                state := intArg(args[2], "state", 0, activeCA.states - 1) or_return
                for i in 0..<val {
                    x, y := rand.int_max(int(GRID_SIZE)),rand.int_max(int(GRID_SIZE))
                    setCellState(x, y, activeGrid, state)
                }
                return "PLACED"
            }
            case "clear": {
                reset_log()
                fillCells(activeGrid, {0,nil,nil})
                stepsPerTick = 1
                updateRate = 5
                return nil
            }
            case "auto", "a": {
                if (len(args) == 1) {
                    return fmt.tprintf("Cur auto: %s", activeCAName)
                }
                argCount(len(args), 1, "auto") or_return
                name := args[1]
                if name == "?" || name == "list" {
                    ret := "Available autos"
                    // Sort keys in array
                    names := make([]string, len(autos))
                    defer delete(names)
                    nameIndex := 0
                    for k, _ in autos {
                        names[nameIndex] = k
                        nameIndex += 1
                    }
                    slice.sort(names)
                    for name in names {
                        ret = fmt.tprintf("%s\n- %s",ret, name)
                    }
                    return ret
                }
                if name not_in autos {
                    return fmt.tprintf("Invalid auto name '%s'", name)
                }
                changeAuto(name)
                return fmt.tprintf("Changed to '%s'", name)
            }
            case "rate", "r": {
                argCount(len(args), 1, "auto") or_return
                val := intArg(args[1], "rate") or_return
                updateRate = val
                return fmt.tprintf("Set update rate to '%d'", updateRate)
            }
            case "reload": {
                if !reloadAllXML() {
                    return "Could not load autos.xml"
                } else {
                    // Cleanup
                    if activeCAName in autos {
                        activeCA = autos[activeCAName]
                        // Don't need to clear
                    } else {
                        activeCA = autos["gol"]
                        fillCells(activeGrid, {0,nil,nil})
                    }
                    return "Loaded autos.xml"
                }
            }
            case "steps": {
                argCount(len(args), 1, "steps") or_return
                val := intArg(args[1], "rate", 0, 10) or_return
                stepsPerTick = val
                return "Updated Steps per tick"
            }
            case "scatter": {
                argCount(len(args), 1, "scatter") or_return
                val := intArg(args[1], "amount", 0, 10000) or_return
                for i := 0; i < activeCA.states; i += 1 {
                    for j in 0..<val {
                        x, y := rand.int_max(int(GRID_SIZE)),rand.int_max(int(GRID_SIZE))
                        setCellState(x, y, activeGrid, i)
                    }
                }
                return "Scattered"
            }
            case "test": {
                // Same as auto <name> + scatter N_CELLS/<N_STATES> 
                if (len(args) != 1) {

                    argCount(len(args), 1, "test") or_return
                    name := args[1]
                    if name == "?" || name == "list" {
                        ret := "Available autos"
                        for k, _ in autos {
                            ret = fmt.tprintf("%s\n- %s",ret, k)
                        }
                        return ret
                    }
                    if name not_in autos {
                        return fmt.tprintf("Invalid auto name '%s'", name)
                    }
                    changeAuto(name)
                }
                val := (GRID_SIZE * GRID_SIZE) / i32(activeCA.states)
                for i := 0; i < activeCA.states; i += 1 {
                    for j in 0..<val {
                        x, y := rand.int_max(int(GRID_SIZE)),rand.int_max(int(GRID_SIZE))
                        setCellState(x, y, activeGrid, i)
                    }
                }
                return ""
            }
            case "probe": {
                toProbe := activeCAName
                if len(args) != 1 {
                    toProbe = args[1]
                }
                if toProbe not_in autos {
                    return fmt.tprintf("Auto '%s' does not exist", toProbe)
                }
                a := autos[toProbe]
                sb: strings.Builder
                fmt.sbprintf(&sb, "Auto '%s'\n", toProbe)

                for ts,i in a.ts {
                    fmt.sbprintf(&sb, "  %d => %d%s\n", i, ts.default, len(ts.rules) == 0 ? "" : "")
                    for rule in ts.rules {
                        fmt.sbprintf(&sb, "    %s => %d\n", rule.cond, rule.endState)
                    }
                }
                out := fmt.tprintf("%s", strings.to_string(sb))
                strings.builder_destroy(&sb)
                return out
            }
            case "help", "?": {
                ret := "Available commands"
                for s in COMMANDS {
                    ret = fmt.tprintf("%s\n- %s",ret, s[0])
                }
                return ret
            }
            // Default case falls through
        }
    }
    return fmt.tprintf("Invalid input '%s'", input)
}

// Simple arg count check
argCount :: proc(count, expected: int, commandName: string) -> union{string} {
    if count - 1 < expected {
        return fmt.tprintf("Command %s requires %d arguments, but got only %d", commandName, expected, count)
    }
    return nil
}

// Simple int arg check
intArg :: proc(s, name: string, minV := 0, maxV := 0) -> (int, union{string}) {
    val, ok := strconv.parse_int(s)
    if !ok {
        return val, fmt.tprintf("Invalid number argument of '%s' for %s", s, name)
    }
    // Allow any value
    if minV == 0 && maxV== 0 {
        return val, nil
    }
    // Bounds Checking
    if val < minV {
        return val, fmt.tprintf("Number argument of '%s' for %s is too small. Min is %d", s, name, minV)
    }
    if val > maxV {
        return val, fmt.tprintf("Number argument of '%s' for %s is too large. Max is %d", s, name, maxV)
    }
    return val, nil
}