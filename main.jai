
State :: struct {
    window : WindowCreation.Window_Type;
    window_width : s32;
    window_height : s32;
    working_directory_set : bool;
    font: *Simp.Dynamic_Font;
    current_time: float64;
}
__s : State;

main :: () {
    __s.window = WindowCreation.create_window(2800, 1500, "Draw Lines");
    __s.window_width, __s.window_height = Simp.get_render_dimensions(__s.window);
    Simp.set_render_target(__s.window);
    init_fonts();
    GetRect.ui_init();
    quit := false;
    while !quit {
        __s.current_time = Basic.seconds_since_init();
        Input.update_window_events();
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == __s.window {
                should_reinit := (it.width != __s.window_width) || (it.height != __s.window_height);
                __s.window_width  = it.width;
                __s.window_height = it.height;
                if should_reinit init_fonts();  // Resize the font for the new window size.
            }
        }
        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;
            if it.type == .KEYBOARD {
                if !it.repeat {
                    //key : string = #char it.key_code;
                    Basic.print("Key pressed %\n", it.key_code);
                }
            }
        }
        draw_one_frame();
        Basic.sleep_milliseconds(10);
    }
}

init_fonts :: () {
    if !__s.working_directory_set {
        path := String.path_strip_filename(System.get_path_of_running_executable());
        Basic.set_working_directory(path);
        __s.working_directory_set = true;
    }
    pixel_height := __s.window_height / 24;
    __s.font = Simp.get_font_at_size("../data", "OpenSans-BoldItalic.ttf", pixel_height);
    Basic.assert(__s.font != null);
}

draw_one_frame :: () {
    Simp.clear_render_target(0.0, .00, .08, 1);
    x, y, width, height := WindowCreation.get_dimensions(__s.window, true);
    GetRect.ui_per_frame_update(__s.window, width, height, __s.current_time);
    k := __s.window_height * .06;
    r := GetRect.get_rect(k*.5, 6.1*k, 5*k, k);
    pressed := GetRect.button(r, "Show Parcels");
    Simp.set_shader_for_color();
    using Math;
    p0, p1 : Vector2;
    p0 = .{200, 100};
    p1 = .{__s.window_width.(float)/2, __s.window_height.(float)/2};
    draw_line(p0, p1, 100.0);
    Simp.swap_buffers(__s.window);
}

draw_line :: (l1:Math.Vector2, l2: Math.Vector2, width:float) {
    using Math;

    line_dx     := l2.x - l1.x;
    line_dy     := l2.y - l1.y;

    inverse_radian := Math.atan(line_dx/line_dy);
    radian_with_90_degrees := Math.PI - inverse_radian;

    radian      := radian_with_90_degrees - Math.PI / 2;
    angle       := radian / Math.PI * 180;
    
    h_1a        := width/ 2.;
    sin_radian  := sin(radian); 
    cos_radian  := cos(radian);
    dx          := sin_radian * h_1a; // soh opposite, horizontal
    dy          := cos_radian * h_1a; // cah adjacent, vertical

    p0, p1, p2, p3 : Vector3;
    p0 = .{l1.x - dx, l1.y + dy, 0};
    p1 = .{l2.x - dx, l2.y + dy, 0};
    p2 = .{l2.x + dx, l2.y - dy, 0};
    p3 = .{l1.x + dx, l1.y - dy, 0};

    color := Vector4.{0.5, 0, 0, 1};
    Simp.immediate_quad(p0, p1, p2, p3, color);
}

GetRect :: #import "GetRect";
Input :: #import "Input";
WindowCreation :: #import "Window_Creation";
Simp :: #import "Simp";
Basic :: #import "Basic";
Math :: #import "Math";
String :: #import "String";
System :: #import "System";

Compiler :: #import "Compiler";
// build
#run {
    Compiler.set_build_options_dc(.{output_path="bin", output_executable_name="draw_lines"});
}
