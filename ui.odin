package cells

import "core:fmt"
import "core:unicode/utf8"
import rl "vendor:raylib"
import mu "vendor:microui"

// Mostly stolen from the examples

// Handle Inputs going to UI
handleUIInputs :: proc() {
    ctx := &state.mu_ctx
    
    // text input
    text_input: [512]byte = ---
    text_input_offset := 0
    for text_input_offset < len(text_input) {
        ch := rl.GetCharPressed()
        if ch == 0 do break
        b, w := utf8.encode_rune(ch)
        copy(text_input[text_input_offset:], b[:w])
        text_input_offset += w
    }
    mu.input_text(ctx, string(text_input[:text_input_offset]))
    
    // mouse coordinates
    mouse_pos := [2]i32{rl.GetMouseX(), rl.GetMouseY()}
    mu.input_mouse_move(ctx, mouse_pos.x, mouse_pos.y)
    mu.input_scroll(ctx, 0, i32(rl.GetMouseWheelMove() * -30))
    
    // mouse buttons
    @static buttons_to_key := [?]struct{
        rl_button: rl.MouseButton,
        mu_button: mu.Mouse,
    }{{.LEFT, .LEFT}, {.RIGHT, .RIGHT}, {.MIDDLE, .MIDDLE}}
    for button in buttons_to_key {
        if rl.IsMouseButtonPressed(button.rl_button) { 
            mu.input_mouse_down(ctx, mouse_pos.x, mouse_pos.y, button.mu_button)
        } else if rl.IsMouseButtonReleased(button.rl_button) { 
            mu.input_mouse_up(ctx, mouse_pos.x, mouse_pos.y, button.mu_button)
        }
    }

    // keyboard
    @static keys_to_check := [?]struct{
        rl_key: rl.KeyboardKey, mu_key: mu.Key,
    }{
        {.LEFT_SHIFT,    .SHIFT},
        {.RIGHT_SHIFT,   .SHIFT},
        {.LEFT_CONTROL,  .CTRL},
        {.RIGHT_CONTROL, .CTRL},
        {.LEFT_ALT,      .ALT},
        {.RIGHT_ALT,     .ALT},
        {.ENTER,         .RETURN},
        {.KP_ENTER,      .RETURN},
        {.BACKSPACE,     .BACKSPACE},
    }
    for key in keys_to_check {
        if rl.IsKeyPressed(key.rl_key) {
            mu.input_key_down(ctx, key.mu_key)
        } else if rl.IsKeyReleased(key.rl_key) {
            mu.input_key_up(ctx, key.mu_key)
        }
    }
        
}

// Initialize the UI
initUI :: proc() {
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH*mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = {0xff, 0xff, 0xff, alpha}
    }
    defer delete(pixels)
        
    image := rl.Image{
        data = raw_data(pixels),
        width   = mu.DEFAULT_ATLAS_WIDTH,
        height  = mu.DEFAULT_ATLAS_HEIGHT,
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8A8,
    }
    state.atlas_texture = rl.LoadTextureFromImage(image)

    ctx := &state.mu_ctx
    mu.init(ctx)

    ctx.text_width = mu.default_atlas_text_width
    ctx.text_height = mu.default_atlas_text_height

}

// Deinitialize the UI
cleanupUI :: proc() {
    rl.UnloadTexture(state.atlas_texture)
}

// Draw everything with the UI
drawUI :: proc() {
    using mu
    ctx := &state.mu_ctx
    begin(ctx)
        all_windows(ctx)
    end(ctx)
    render(ctx)
}

state : struct {
    mu_ctx:             mu.Context,
    log_buf:         [1<<16]byte,
    log_buf_len:     int,
    log_buf_updated: bool,
    bg:              mu.Color,
    atlas_texture:      rl.Texture2D,
} = {
    bg = {90, 95, 100, 255},
}

// Render the UI
render :: proc(ctx: ^mu.Context) {
    render_texture :: proc(rect: mu.Rect, pos: [2]i32, color: mu.Color) {
        source := rl.Rectangle{
            f32(rect.x),
            f32(rect.y),
            f32(rect.w),
            f32(rect.h),
        }
        position := rl.Vector2{f32(pos.x), f32(pos.y)}
        rl.DrawTextureRec(state.atlas_texture, source, position, transmute(rl.Color)color)
    }
    
    rl.BeginScissorMode(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight())
    defer rl.EndScissorMode()
    
    command_backing: ^mu.Command
    for variant in mu.next_command_iterator(ctx, &command_backing) {
        switch cmd in variant {
        case ^mu.Command_Text:
            pos := [2]i32{cmd.pos.x, cmd.pos.y}
            for ch in cmd.str do if ch&0xc0 != 0x80 {
                r := min(int(ch), 127)
                rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
                render_texture(rect, pos, cmd.color)
                pos.x += rect.w
            }
        case ^mu.Command_Rect:
            rl.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, transmute(rl.Color)cmd.color)
        case ^mu.Command_Icon:
            rect := mu.default_atlas[cmd.id]
            x := cmd.rect.x + (cmd.rect.w - rect.w)/2
            y := cmd.rect.y + (cmd.rect.h - rect.h)/2
            render_texture(rect, {x, y}, cmd.color)
        case ^mu.Command_Clip:
            rl.EndScissorMode()
            rl.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
        case ^mu.Command_Jump: 
            unreachable()
        }
    }
}
// Simple slider shortcut
u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
    mu.push_id(ctx, uintptr(val))
    
    @static tmp: mu.Real
    tmp = mu.Real(val^)
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
    val^ = u8(tmp)
    mu.pop_id(ctx)
    return
}

write_log :: proc(str: string) {
    out := runCommand(str)
    if out == nil || out.(string) == "" do return
    state.log_buf_len += copy(state.log_buf[state.log_buf_len:], out.(string))
    state.log_buf_len += copy(state.log_buf[state.log_buf_len:], "\n")
    state.log_buf_updated = true
}

read_log :: proc() -> string {
    return string(state.log_buf[:state.log_buf_len])
}
reset_log :: proc() {
    state.log_buf_updated = true
    state.log_buf_len = 0
}


all_windows :: proc(ctx: ^mu.Context) {
    @static opts := mu.Options{.NO_CLOSE, .NO_RESIZE, .NO_INTERACT}
    
    if mu.window(ctx, "Commands", {SCREEN_SIZE, 0, SIDE_WINDOW_WIDTH, i32(f32(SCREEN_SIZE) * SIDE_WINDOW_HIGHT_PERCENT)}, opts) {
        mu.layout_row(ctx, {-1}, -28)
        mu.begin_panel(ctx, "Log")
            mu.layout_row(ctx, {-1}, -1)
            mu.text(ctx, read_log())
            if state.log_buf_updated {
                panel := mu.get_current_container(ctx)
                panel.scroll.y = panel.content_size.y
                state.log_buf_updated = false
            }
        mu.end_panel(ctx)
        
        @static buf: [128]byte
        @static buf_len: int
        submitted := false
        mu.layout_row(ctx, {-70, -1})
        if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
            mu.set_focus(ctx, ctx.last_id)
            submitted = true
        }
        if .SUBMIT in mu.button(ctx, "Submit") {
            submitted = true
        }
        if submitted {
            write_log(string(buf[:buf_len]))
            buf_len = 0
        }
    }
}