
Line :: struct {
    p1: Vector2;
    p2: Vector2;
}

Draw_Options :: struct {
    name: string;
    value := false;
}

State :: struct {
    window : WindowCreation.Window_Type;
    window_width : s32;
    window_height : s32;
    theme : Overall_Theme;
    working_directory_set : bool;
    font: *Simp.Dynamic_Font;
    vectors: [..] Vector2;
    mouse_press_pos: Vector2 = .{-1,-1}; 
    primary_color: Vector3 = .{0.54, 0.79, 0.77};
    secondary_color: Vector3 = .{0.15, 0.37, 0.37};
    scroll_value_dragdrop_region: float;
    draw_options: [..] Draw_Options;
    button_theme: Button_Theme;
    draw_line_start: s32 = 0;
    draw_line_limit: s32 = 0;
    loop_drawing:= false;
    loop_speed :float= 1;
    loop_timer :float64 = 0;
}

__s : State;
main :: () {
  __s.window = WindowCreation.create_window(2800, 2000, "Draw Shapes");
  __s.window_width, __s.window_height = Simp.get_render_dimensions(__s.window);
  msaa := Simp.prepare_window(__s.window, wanted_msaa = 8);

  Simp.set_render_target(__s.window, .LEFT_HANDED);
  init_fonts();
  ui_init();
  quit := false;

  g := array_add(*__s.draw_options);
  g.name = "Triangles";
  g.value = true;

  g = array_add(*__s.draw_options);
  g.name = "Dot Product";
  g.value = false;

  while !quit {
    start_time = current_time_monotonic();
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
    k := __s.window_height * .05;
    for Input.events_this_frame {
      x, y := WindowCreation.get_mouse_pointer_position(__s.window, false);
      if it.type == .QUIT then quit = true;

      if it.type == .MOUSE_WHEEL{
        __s.draw_line_start -= xx (it.wheel_delta * 0.15);
        if (__s.draw_line_start > __s.vectors.count - 1) {
          __s.draw_line_start = 0;
        }
        if (__s.draw_line_start < 0) {
          __s.draw_line_start = cast(s32) __s.vectors.count - 1;
        }
      }
      if it.type == .KEYBOARD {

        if !it.repeat {
          if it.key_pressed {
            if it.key_code == {
              case #char "R";
              array_reset(*__s.vectors);
              case #char "2";
            }
          }
          if xx x > 5 * k {
            if it.key_pressed {
              if it.shift_pressed && it.key_code == .ARROW_RIGHT {
                __s.draw_line_limit += 1;
                if (__s.draw_line_limit > __s.vectors.count) {
                  __s.draw_line_limit = cast(s32) __s.vectors.count;
                }
              } else if it.key_code == .ARROW_RIGHT {
                __s.draw_line_start += 1;
                if (__s.draw_line_start > __s.vectors.count -1) {
                __s.draw_line_start = 0;
                }
              }
              if it.shift_pressed && it.key_code == .ARROW_LEFT {
                __s.draw_line_limit -= 1;
                if (__s.draw_line_limit < 1) {
                  __s.draw_line_limit = 1;
                }
              } else if it.key_code == .ARROW_LEFT {
                __s.draw_line_start -= 1;
                if (__s.draw_line_start < 0) {
                __s.draw_line_start = cast(s32) __s.vectors.count - 1;
                }
              }
              if it.key_code == .MOUSE_BUTTON_LEFT || it.key_code == .SPACEBAR {
                  __s.mouse_press_pos = .{xx x, xx y};
                  if __s.draw_line_limit == __s.vectors.count  {
                    __s.draw_line_limit += 1;
                  }
                  array_add(*__s.vectors, .{xx x, xx y});
              }
            }
          }
        }
      }
    }
    draw_one_frame();
  }
}

init_fonts :: () {
  if !__s.working_directory_set {
      path := String.path_strip_filename(System.get_path_of_running_executable());
      set_working_directory(path);
      __s.working_directory_set = true;
  }
  pixel_height := __s.window_height / 50;
  free(__s.font);
  __s.font = Simp.get_font_at_size("../data", "OpenSans-BoldItalic.ttf", pixel_height);
  assert(__s.font != null);
}

TestEnum :: enum {
  Testing1;
  Testing2;
  Testing3;
}

start_time : Apollo_Time;

Triangle :: struct {
  p1: Vector2;
  p2: Vector2;
  p3: Vector2;
}


draw_one_frame :: () {
  proc := default_theme_procs[ Default_Themes.Default ];
  __s.theme = proc();
  set_default_theme(__s.theme);

  __s.button_theme = __s.theme.button_theme;
  __s.button_theme.font = __s.font;

  bg_col := __s.theme.background_color;
  Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

  {
    _, _, width, height := WindowCreation.get_dimensions(__s.window, true);
    ui_per_frame_update(__s.window, width, height, to_float64_seconds(current_time_monotonic()));

  }

  // 'k' is some resolution-adjusting unit of distance. Right now it is
  // 1/10 of the screen height, so, 100 pixels at 1920x2000.
  k := __s.window_height * .05;


  Simp.set_shader_for_color();
  Simp.immediate_begin();


  // UI

  mouse_x, mouse_y := WindowCreation.get_mouse_pointer_position(__s.window, false);
  if mouse_x < 500 {
    r := get_rect(0*k, 0*k, 5*k, 20*k);

    theme := __s.theme.scrollable_region_theme;
    region, inside := begin_scrollable_region(r, *theme);
    s := inside;
    s.y = s.y;
    s.h = xx __s.font.character_height;
    s.y -= __s.scroll_value_dragdrop_region;

    checkbox_theme := __s.theme.checkbox_theme;
    for * __s.draw_options {
      pressed := base_checkbox(s, it.name, it.value, *checkbox_theme, it_index);
      it.value ^= pressed;
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
    }

    slider_theme := __s.theme.slider_theme;
    slider_theme.foreground.font = __s.font;
    slider_theme.surface_style = .NUB;
    slider(s, *__s.draw_line_start, 0, xx __s.vectors.count, 1, *slider_theme, "start ");
    if __s.draw_line_start > __s.vectors.count - 1 {
      if (__s.vectors.count > 0) {
        __s.draw_line_start = cast(s32) __s.vectors.count - 1;
      } else {
        __s.draw_line_start = 0;
      }
    }
    s.y += s.h * 1.2;

    slider(s, *__s.draw_line_limit, 0, xx __s.vectors.count, 1, *slider_theme, "limit ");
    s.y += s.h * 1.2;

    slider(s, *__s.loop_speed, 0, 10, 1, *slider_theme, "speed ");
    s.y += s.h * 1.2;

    {
      pressed := base_checkbox(s, "Loop", __s.loop_drawing, *checkbox_theme, 0);
      __s.loop_drawing ^= pressed;
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
    }
    {
      pressed := button(s, "Reset", *__s.button_theme);
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
      if pressed  {
        array_reset(*__s.vectors);
        __s.draw_line_start = 0;
        __s.draw_line_limit = 0;
      }
    }

    aspect := get_desired_aspect_ratio(*__s.theme.color_picker_theme);

    {
      s.y += 1 * k;
      picker := get_rect(s.x, s.y, s.w, 5*k/aspect);
      color_picker_theme := *__s.theme.color_picker_theme;
      applied := color_picker(picker, *__s.secondary_color, color_picker_theme);
      s.y += picker.h;
    }

    {
      s.y += 1 * k;
      picker := get_rect(s.x, s.y, s.w, 5*k/aspect);
      color_picker_theme := *__s.theme.color_picker_theme;
      applied := color_picker(picker, *__s.primary_color, color_picker_theme);
      s.y += picker.h;
    }

    end_scrollable_region(region, s.x + s.w, s.y, *__s.scroll_value_dragdrop_region);

  } // end show ui

  // draw outlines
  for 1..__s.vectors.count - 1 {
    draw_line(__s.vectors[it -1], __s.vectors[it], 10.0, __s.secondary_color);
  }
  // draw last outline
  if (__s.vectors.count > 2) {
    draw_line(__s.vectors[__s.vectors.count - 1], __s.vectors[0], 10.0, __s.secondary_color);
  }

  // @todo- separate out creation of triangles from the drawing of the triangles
  // then use the determinant to detect winding order
  // https://github.com/Muzkaw/Ear-clipping-triangulation/blob/master/Ear%20clipping%20triangulation/Triangulation.cpp


  if (__s.vectors.count > 2) {
    //
    // draw triangles
    // 
    final_idx := __s.vectors.count - 1;
    if (final_idx >= __s.draw_line_start + __s.draw_line_limit) {
      final_idx = __s.draw_line_start + __s.draw_line_limit;
    }

    v : [..] Vector2;
    v.allocator = temp;
    for __s.draw_line_start .. final_idx {
      array_add(*v, __s.vectors[it]);
    }

    color : Vector4 = .{1,1,1,1};
    color.xyz = __s.secondary_color;

    mouse:Vector2;
    mouse.x, mouse.y = xx WindowCreation.get_mouse_pointer_position(__s.window, false);

    while v.count > 2 {
      // check if this triangle has any values in it.
      if __s.draw_options[0].value {
        color:= Vector4.{1,1,1,1};
        color.xyz = __s.secondary_color;
        if is_vertex_inside_triangle(v[2], v[1], v[0], mouse) {
          color.xyz = __s.primary_color;
        }
        //if true {
        //if !is_another_vertex_inside_triangle(v[0], v[1], v[2], array_view(v, 2)) &&
           if is_vertex_in_right_winding_order(v[0], v[1], v[2]) {
          Simp.immediate_triangle(
            .{v[0].x, v[0].y, 1.0}, 
            .{v[1].x, v[1].y, 0}, 
            .{v[2].x, v[2].y, 0}, 
            color, color, color);
          draw_line(v[0], v[1], 10, __s.primary_color);
          draw_line(v[0], v[2], 10, __s.primary_color);
          draw_line(v[2], v[1], 10, __s.primary_color);
          array_ordered_remove_by_index(*v, 1);
        } else {
          array_ordered_remove_by_index(*v, 0);
        }
      } // if
    } // while
    
    //
    // end draw triangles
    // 


    // draw angles
    /*
    {
      k := __s.window_height * .05;
      label_theme := __s.theme.label_theme;
      label_theme.font = __s.font;
      label_theme.alignment = .Left;
      //label_theme.text_color.xyz = color;
      // draw angles
      for idx: 0 .. __s.vectors.count - 2 {
        p1 := __s.vectors[idx];
        p2 := __s.vectors[idx+1];
        r := get_rect(p1.x - 1 * k, p1.y, 4 * k, 1 * k);
        delta := p1 - p2;
        angle := atan(delta.y / delta.x) / PI * 180;
        label(r, tprint("angle: %", angle), *label_theme);
      }
    }
    */

    // draw winding order
    /*
    {
      k := __s.window_height * .05;
      label_theme := __s.theme.label_theme;
      label_theme.font = __s.font;
      label_theme.alignment = .Left;
      //label_theme.text_color.xyz = color;
      for idx: 0 .. __s.vectors.count - 2 {
        p1 := __s.vectors[idx];
        p2 := __s.vectors[idx+1];
        r := get_rect(p1.x - 1 * k, p1.y, 4 * k, 1 * k);
        delta := p2 - p1;
        label(r, tprint("product: %", delta.x * delta.y), *label_theme);
      }
    }
    */

    //
    // draw dot product
    // 

    if(__s.draw_options[1].value) {
      for __s.draw_line_start + 1..__s.vectors.count -1 {
        if (it > __s.draw_line_start + __s.draw_line_limit) break;
        draw_dot_product(__s.vectors[it-1], __s.vectors[it], .{xx mouse.x, xx mouse.y});
      }
    }
  }


  Simp.immediate_flush();
  Simp.swap_buffers(__s.window);
  memory_visualizer_per_frame_update();

  sleep_milliseconds(1); 
  if __s.loop_drawing {
    now := current_time_monotonic();
    ms_passed:= to_milliseconds(now - start_time);
    __s.loop_timer += ms_passed * __s.loop_speed; 
    if __s.loop_timer > 100 {
      __s.loop_timer = 0;
      __s.draw_line_start += 1;
      if (__s.draw_line_start > __s.vectors.count -1) {
      __s.draw_line_start = 0;
      }
    }
  }
  reset_temporary_storage();

}
determinant :: (p1:Vector2, p2:Vector2) -> float {
  return p1.x*p2.y - p1.y*p2.x;
}

is_vertex_in_right_winding_order :: (a:Vector2, b:Vector2, c:Vector2) -> bool {
  return determinant(b-a, c-b) > 0;
}

is_vertex_inside_triangle :: (a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool {
  ab := b - a;
  bc := c - b;
  ca := a - c;

  return determinant(ab, point-a) < 0 && 
         determinant(bc, point-b) < 0 && 
         determinant(ca, point-c) < 0;
}

is_another_vertex_inside_triangle :: (p1:Vector2, p2:Vector2, p3:Vector2, arr: [] Vector2) -> bool {
  for point: arr {
    if is_vertex_inside_triangle(p1, p2, p3, point)
    {
      return true;
    }
  }
  return false;
}


draw_dot_product :: (origin:Vector2, v1:Vector2, mouse:Vector2) {

  rotated_point := v1 - origin;
  rotated_point = .{rotated_point.y, -rotated_point.x};

  // outside
  color := Vector3.{0.91,0.22,0.52};


  dot_product_1 := dot_product(rotated_point, mouse - origin);

  if dot_product_1 < 0 {
    // inside
    color = .{0.07,0.48,0.34};
  }

  draw_line(origin, origin + rotated_point, 1, color);
  /*

  label_theme := __s.theme.label_theme;
  label_theme.text_color.xyz = color;

  //label_theme.alignment = .Left;
  k := __s.window_height * .05;
  r := get_rect(origin.x, origin.y, k * 6, k * 1);
  label_text := tprint("dot: % %", ifx dot_product_1 > 0 then "+" else "-", dot_product_1);
  label(r, label_text, *label_theme);
  */
}

draw_line :: (l1:Vector2, l2: Vector2, width:float, color: Vector3 ) {

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

  Simp.immediate_quad(p0, p1, p2, p3, .{color.x, color.y, color.z, 1});
}

#import "GetRect_LeftHanded";
Input :: #import "Input";
WindowCreation :: #import "Window_Creation";
Simp :: #import "Simp";

#import "Basic";
//#import "Basic"()(MEMORY_DEBUGGER=true);


/*
using,only(
    Vector2,
    Vector4
) Math :: #import "Math";
*/
#import "Math";

String :: #import "String";
System :: #import "System";

