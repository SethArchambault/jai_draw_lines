
Line :: struct {
    p1: Vector2;
    p2: Vector2;
}

State :: struct {
    window : WindowCreation.Window_Type;
    window_width : s32;
    window_height : s32;
    working_directory_set : bool;
    font: *Simp.Dynamic_Font;
    current_time: float64;
    vectors: [..] Vector2;
    mouse_press_pos: Vector2 = .{-1,-1}; 
    primary_color: Vector4 = .{0.5, 0, 0, 1};
    secondary_color: Vector4 = .{0, 0.2, 0, 1};
}
__s : State;
main :: () {
  __s.window = WindowCreation.create_window(2800, 1500, "Draw Shapes");
  __s.window_width, __s.window_height = Simp.get_render_dimensions(__s.window);
  Simp.set_render_target(__s.window);
  init_fonts();
  GetRect.ui_init();
  quit := false;
  while !quit {
    __s.current_time = seconds_since_init();
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
            print("key pressed\n");
            if it.key_code == {
              case #char "R";
              print("r is working\n");
              array_reset(*__s.vectors);
              //print("%", __s.p1);
              case #char "2";
              print("2 tapped\n");
            }
          }
          if it.key_code == .MOUSE_BUTTON_LEFT {
            if (it.key_pressed)  {
              __s.mouse_press_pos = .{xx x, xx y};
              array_add(*__s.vectors, .{xx x, xx y});
            } 
          }
        }
      }
    }
    draw_one_frame();
    sleep_milliseconds(10);
  }
}

init_fonts :: () {
  if !__s.working_directory_set {
      path := String.path_strip_filename(System.get_path_of_running_executable());
      set_working_directory(path);
      __s.working_directory_set = true;
  }
  pixel_height := __s.window_height / 24;
  __s.font = Simp.get_font_at_size("../data", "OpenSans-BoldItalic.ttf", pixel_height);
  assert(__s.font != null);
}

draw_one_frame :: () {
  Simp.clear_render_target(0.0, .00, .08, 1);
  {
    _, _, width, height := WindowCreation.get_dimensions(__s.window, true);
    GetRect.ui_per_frame_update(__s.window, width, height, __s.current_time);
  }
  k := __s.window_height * .06;

  //pressed := GetRect.button(r, "Show Parcels");
  Simp.set_shader_for_color();
  Simp.immediate_begin();
  for 1..__s.vectors.count - 1 {
    draw_line(__s.vectors[it -1], __s.vectors[it], 10.0);
  }
  for 2..__s.vectors.count - 2 {
    draw_line(__s.vectors[0], __s.vectors[it], 10.0);
  }
  if (__s.vectors.count > 2) {
    draw_line(__s.vectors[__s.vectors.count - 1], __s.vectors[0], 10.0);
  }

  if (__s.vectors.count > 2) {
    // how do I make a copy of vectors
    v := array_copy(__s.vectors);

    origin := v[0];
    color := __s.secondary_color; 

    x, y:= WindowCreation.get_mouse_pointer_position(__s.window, true);

    idx :u32= 1;
    // maybe we should do count - 2
    while idx < v.count-1 {
      p1 := v[idx-1 % v.count];
      p2 := v[idx];
      p3 := v[idx+1 % v.count]; // maybe we should just not do this for the last one.

      // check if this triangle has any values in it.
      Simp.immediate_triangle(
        .{p1.x, p1.y, 0}, 
        .{p2.x, p2.y, 0}, 
        .{p3.x, p3.y, 0}, 
        color, color, color);
      draw_line(p1, p3, 10);
      array_ordered_remove_by_index(*v, idx);
    }
    for 1..__s.vectors.count -1 {
      draw_dot_product(__s.vectors[it-1], .{xx x, xx y}, __s.vectors[it]);
    }

    draw_dot_product(__s.vectors[__s.vectors.count-1], .{xx x, xx y}, __s.vectors[0]);
  }


  Simp.immediate_flush();
  Simp.swap_buffers(__s.window);
}

draw_dot_product :: (origin:Vector2,v1:Vector2,v2:Vector2) {
  p1 := v2 - origin;
  p1 = .{-p1.y, p1.x};
  draw_line(origin, origin + p1, 1);
  dot_product_1 := dot_product(v1 - origin, p1);
  my_theme : GetRect.Overall_Theme;
  GetRect.set_default_theme(my_theme);
  label_theme := my_theme.label_theme;

  label_theme.alignment = .Left;
  label := tprint("dot: %", ifx dot_product_1 > 0 then "+" else "-");
  r := GetRect.get_rect(origin.x, origin.y, 1000, 100);
  GetRect.label(r, label, *label_theme);
}

draw_line :: (l1:Vector2, l2: Vector2, width:float) {

  line_dx     := l2.x - l1.x;
  line_dy     := l2.y - l1.y;

  inverse_radian := atan(line_dx/line_dy);
  radian_with_90_degrees := PI - inverse_radian;

  radian      := radian_with_90_degrees - PI / 2;
  angle       := radian / PI * 180;
  
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
  color := __s.primary_color;

  Simp.immediate_quad(p0, p1, p2, p3, color);
}

GetRect :: #import "GetRect";
Input :: #import "Input";
WindowCreation :: #import "Window_Creation";
Simp :: #import "Simp";

#import "Basic";


/*
using,only(
    Vector2,
    Vector4
) Math :: #import "Math";
*/
#import "Math";

String :: #import "String";
System :: #import "System";

Compiler :: #import "Compiler";
// build
#run {
   Compiler.set_build_options_dc(.{output_path="bin", output_executable_name="draw_lines"});
}
