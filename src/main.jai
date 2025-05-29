
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
    Simp.set_shader_for_color();
    using Math;
    p0 := Vector2.{200, 100};
    p1 := Vector2.{__s.window_width.(float)/2, __s.window_height.(float)/2};
    draw_line(p0, p1, 100.0);
    Simp.swap_buffers(__s.window);
}

draw_line :: (l1:Math.Vector2, l2: Math.Vector2, width:float) {
    using Math;
    p0 := Vector3.{l1.x, l1.y, 0};
    p1 := Vector3.{l1.x, l1.y + width, 0};
    p2 := Vector3.{l2.x, l2.y + width, 0};
    p3 := Vector3.{l2.x, l2.y, 0};
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

