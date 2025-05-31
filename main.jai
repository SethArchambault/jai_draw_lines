
Line :: struct {
    p1: Math.Vector2;
    p2: Math.Vector2;
}

State :: struct {
    window : WindowCreation.Window_Type;
    window_width : s32;
    window_height : s32;
    working_directory_set : bool;
    font: *Simp.Dynamic_Font;
    current_time: float64;
    lines: [..] Line;
    mouse_press_pos: Math.Vector2 = .{-1,-1}; 
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
            //print("% %\n", it.type, it.key_code);
            if it.type == .KEYBOARD {
                x, y := WindowCreation.get_mouse_pointer_position(__s.window, true);

                if !it.repeat {
                    if it.key_pressed {
                        if it.key_code == {
                            case #char "1";
                            //print("%", __s.p1);
                            case #char "2";
                            //print("%", __s.p2);
                        }
                    }
                    if it.key_code == .MOUSE_BUTTON_LEFT {
                        if (it.key_pressed)  {
                            __s.mouse_press_pos = .{x.(float), y.(float)};
                        } else {
                            line: Line = .{
                                p1 = __s.mouse_press_pos,
                                p2 = .{x.(float), y.(float)}
                            };
                            __s.mouse_press_pos = .{-1,-1};
                            Basic.array_add(*__s.lines, line);
                        }
                    }
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
    {
        _, _, width, height := WindowCreation.get_dimensions(__s.window, true);
        GetRect.ui_per_frame_update(__s.window, width, height, __s.current_time);
    }
    k := __s.window_height * .06;
    r := GetRect.get_rect(k*.5, 6.1*k, 5*k, k);
    pressed := GetRect.button(r, "Show Parcels");
    Simp.set_shader_for_color();
    Simp.immediate_begin();
    for __s.lines {
        p2: Math.Vector2;
            p2 = it.p2;
        draw_line(it.p1, p2, 10.0);
    }

    if __s.mouse_press_pos.x != -1 {
        x, y := WindowCreation.get_mouse_pointer_position(__s.window, true);
        mouse_pos: = Math.Vector2.{x.(float), y.(float)};
        draw_line(__s.mouse_press_pos, mouse_pos, 5.0);
    }
    Simp.immediate_flush();
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
using,only(print) Basic :: #import "Basic";
Math :: #import "Math";
String :: #import "String";
System :: #import "System";

Compiler :: #import "Compiler";
// build
#run {
    Compiler.set_build_options_dc(.{output_path="bin", output_executable_name="draw_lines"});
}
