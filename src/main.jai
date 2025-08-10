
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
  g.value = true;

  /*
  g = array_add(*__s.draw_options);
  g.name = "Draw 4";
  g.value = true;
  */




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
      //print("% %\n", it.type, it.key_code);

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
              print("2 tapped\n");
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
  pixel_height := __s.window_height / 40;
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
     {
        r := get_rect(0*k, 0*k, 5*k, 20*k);

        theme := __s.theme.scrollable_region_theme;
        region, inside := begin_scrollable_region(r, *theme);
        s := inside;
        s.y = s.y;
        s.h = xx __s.font.character_height;
        s.y -= __s.scroll_value_dragdrop_region;
        //s.w = 4 * k;


          checkbox_theme := __s.theme.checkbox_theme;
          for * __s.draw_options{
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

      }





  } // end show ui

  // draw outlines
  for 1..__s.vectors.count - 1 {
    draw_line(__s.vectors[it -1], __s.vectors[it], 10.0, __s.secondary_color);
  }
  // draw last outline
  if (__s.vectors.count > 2) {
    draw_line(__s.vectors[__s.vectors.count - 1], __s.vectors[0], 10.0, __s.secondary_color);
  }

  // draw triangle outlines
  /*
  if(__s.draw_options[0].value) {
    for __s.draw_line_start + 2..__s.vectors.count - 2 {
      if (xx it > __s.draw_line_start + __s.draw_line_limit) break;
      draw_line(__s.vectors[0], __s.vectors[it], 10.0, __s.primary_color);
    }
  }
  */

  if (__s.vectors.count > 2) {
    //
    // draw triangles
    // 
    v : [..] Vector2;
    v.allocator = temp;
    final_idx := __s.vectors.count - 1;
    if (final_idx >= __s.draw_line_start + __s.draw_line_limit) {
      final_idx = __s.draw_line_start + __s.draw_line_limit;
    }
    for __s.draw_line_start .. final_idx {
      array_add(*v, __s.vectors[it]);
    }

    color : Vector4 = .{1,1,1,1};
    color.xyz = __s.secondary_color;

    mouse_x, mouse_y := WindowCreation.get_mouse_pointer_position(__s.window, true);

    idx := 0;
    while idx <= v.count-1 {
      p1 : Vector2;
      if idx - 1 < 0 {
        p1 = v[v.count - 1];
      } else {
        p1 = v[idx - 1];
      } // if

      p2 := v[idx];

      p3 : Vector2;
      if (idx + 1) >= v.count {
        p3 = v[0];
      } else {
        p3 = v[idx+1]; // maybe we should just not do this for the last one.
      } // if

      // check if this triangle has any values in it.
      if __s.draw_options[0].value {
        Simp.immediate_triangle(
          .{p1.x, p1.y, 1.0}, 
          .{p2.x, p2.y, 0}, 
          .{p3.x, p3.y, 0}, 
          color, color, color);
        draw_line(p1, p2, 10, __s.primary_color);
        draw_line(p1, p3, 10, __s.primary_color);
        draw_line(p3, p2, 10, __s.primary_color);
      } // if

      array_ordered_remove_by_index(*v, idx);

    } // while
    //
    // end draw triangles
    // 


    //
    // draw dot product
    // 

    if(__s.draw_options[1].value) {
      for __s.draw_line_start + 1..__s.vectors.count -1 {
        if (it > __s.draw_line_start + __s.draw_line_limit) break;
        draw_dot_product(__s.vectors[it-1], __s.vectors[it], .{xx mouse_x, xx mouse_y});
      }

      /* seth
      // connect end to start
      if (__s.draw_line_start + __s.draw_line_limit >= __s.vectors.count-1) {
        draw_dot_product(__s.vectors[__s.vectors.count-1], __s.vectors[0], .{xx mouse_x, xx mouse_y});
      }
      */
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
    print("loop timer %\n", __s.loop_timer);
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

draw_dot_product :: (origin:Vector2, v1:Vector2, mouse:Vector2) {

  rotated_point := v1 - origin;
  rotated_point = .{rotated_point.y, -rotated_point.x};

  // outside
  color := Vector3.{0.91,0.22,0.52};

  adjusted_mouse := Vector2.{mouse.x, __s.window_height - mouse.y};

  dot_product_1 := dot_product(rotated_point, adjusted_mouse - origin);

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

