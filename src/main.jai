
State :: struct {
    window : WindowCreation.Window_Type;
    window_width : s32;
    window_height : s32;
    theme : Overall_Theme;
    font: *Simp.Dynamic_Font;
    vectors: [..] Vector2;
    mouse_press_pos: Vector2  = .{-1,-1}; 
    primary_color:   Vector3  = .{0.54, 0.79, 0.77};
    secondary_color: Vector3  = .{0.15, 0.37, 0.37};
    scroll_value_dragdrop_region: float;
    flags:Flags = .outline | .triangle_fill | .triangle_lines;
    draw_line_start:  s32     = 0;
    draw_line_limit:  s32     = 0;
    loop_speed :      float   = 1;
    loop_timer :      float64 = 0;
    start_time : Apollo_Time;
}

Flags :: enum_flags {
  outline;
  triangle_fill;
  triangle_lines;
  dot_product;
  loop;
  show_ui;
}

__s : State;
main :: () {
  __s.window = WindowCreation.create_window(2800, 2000, "Draw Shapes");
  __s.window_width, __s.window_height = Simp.get_render_dimensions(__s.window);
  msaa := Simp.prepare_window(__s.window, wanted_msaa = 8);

  Simp.set_render_target(__s.window, .LEFT_HANDED);
  path := String.path_strip_filename(System.get_path_of_running_executable());
  set_working_directory(path);
  init_fonts();
  ui_init();
  run := true;

  while run {
    __s.start_time = current_time_monotonic();
    run = handle_input();
    draw_one_frame();
  }
}

handle_input :: () -> bool {
  Input.update_window_events();
  for Input.get_window_resizes() {
    Simp.update_window(it.window);
    if it.window == __s.window {
      should_reinit := (it.width != __s.window_width) || (it.height != __s.window_height);
      __s.window_width  = it.width;
      __s.window_height = it.height;
      if should_reinit {
        init_fonts();  // Resize the font for the new window size.
      }
    }
  }
  k := __s.window_height * .05;
  for Input.events_this_frame {
    mouse_x, mouse_y := WindowCreation.get_mouse_pointer_position(__s.window, false);
    if it.type ==  {
      case .QUIT; 
        return false;
      case .MOUSE_WHEEL;
        __s.draw_line_start -= xx (it.wheel_delta * 0.15);
        if (__s.draw_line_start > __s.vectors.count - 1) {
          __s.draw_line_start = 0;
        }
        if (__s.draw_line_start < 0) {
          __s.draw_line_start = cast(s32) __s.vectors.count - 1;
        }
      case .KEYBOARD;
        if it.key_pressed && !it.repeat {
          if it.key_code == {
            case #char "R";
            array_reset(*__s.vectors);
          }
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

          // ui shouldn't be showing
          if !(__s.flags & .show_ui) {
            if it.key_code == .MOUSE_BUTTON_LEFT || it.key_code == .SPACEBAR {
                __s.mouse_press_pos = .{xx mouse_x, xx mouse_y};
                if __s.draw_line_limit == __s.vectors.count  {
                  __s.draw_line_limit += 1;
                }
                array_add(*__s.vectors, .{xx mouse_x, xx mouse_y});
            } else if 
              it.key_code == .MOUSE_BUTTON_RIGHT || 
              it.key_code == .BACKSPACE 
            {
              distance := 20;
              for __s.vectors {
                if xx it.x > mouse_x - distance && 
                   xx it.x < mouse_x + distance &&
                   xx it.y > mouse_y - distance && 
                   xx it.y < mouse_y + distance 
                {
                  array_ordered_remove_by_index(*__s.vectors, it_index);
                  break;
                }
              }
            } // delete
          } // !show_ui
        } // key pressed
      // case keyboard
      case;
    } // case
  } // events per frame
  return true;
}

init_fonts :: () {
  pixel_height := __s.window_height / 50;
  free(__s.font);
  __s.font = Simp.get_font_at_size("../data", "OpenSans-BoldItalic.ttf", pixel_height);
  assert(__s.font != null);
}


draw_one_frame :: () {
  proc := default_theme_procs[ Default_Themes.Default ];
  __s.theme = proc();
  set_default_theme(__s.theme);

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

  mouse_x, mouse_y := WindowCreation.get_mouse_pointer_position(__s.window, false);
  // draw outlines

  if __s.flags & .outline {
    for 1..__s.vectors.count - 1 {
      draw_line(__s.vectors[it -1], __s.vectors[it], 10.0, __s.secondary_color);
    }

    // draw last outline
    if (__s.vectors.count > 2) {
      draw_line(__s.vectors[__s.vectors.count - 1], __s.vectors[0], 10.0, __s.secondary_color);
    }
  }

  // https://github.com/Muzkaw/Ear-clipping-triangulation/blob/master/Ear%20clipping%20triangulation/Triangulation.cpp

  triangles := triangulate(array_view(__s.vectors, __s.draw_line_start, __s.draw_line_limit));
  
  {
    // draw triangles
    color:= Vector4.{1,1,1,1};
    color.xyz = __s.secondary_color;
    for triangles {
      v := it;
      if __s.flags & .triangle_fill {
        Simp.immediate_triangle(
          .{v.a.x, v.a.y, 1.0}, 
          .{v.b.x, v.b.y, 0}, 
          .{v.c.x, v.c.y, 0}, 
          color, color, color);
      }
      if __s.flags & .triangle_lines {
        draw_line(v.a, v.b, 10, __s.primary_color);
        draw_line(v.a, v.c, 10, __s.primary_color);
        draw_line(v.c, v.b, 10, __s.primary_color);
      }
    }
  }

  //
  // draw dot product
  // 

  if __s.flags &.dot_product {
    for __s.draw_line_start + 1..__s.vectors.count -1 {
      if (it > __s.draw_line_start + __s.draw_line_limit) break;
      draw_dot_product(__s.vectors[it-1], __s.vectors[it], .{xx mouse_x, xx mouse_y});
    }
  }

  //
  // UI
  //

  if mouse_x < 50 {
    __s.flags |= .show_ui;
  } else if mouse_x > 500 {
    __s.flags &= ~.show_ui;
  }

  if __s.flags & .show_ui {
    r := get_rect(0*k, 0*k, 5*k, 20*k);

    theme := __s.theme.scrollable_region_theme;
    region, inside := begin_scrollable_region(r, *theme);
    s := inside;
    s.y = s.y;
    s.h = xx __s.font.character_height;
    s.y -= __s.scroll_value_dragdrop_region;

    for Flags.[ .outline, .triangle_fill, .triangle_lines, .dot_product,] {
      checkbox_flags(s, *__s.flags, it, identifier = it_index);
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

    checkbox_flags(s, *__s.flags, .loop);
    s.y += floor(__s.font.character_height * 1.1 + 0.5);

    {
      pressed := button(s, "Reset", *__s.theme.button_theme);
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
      if pressed  {
        array_reset(*__s.vectors);
        __s.draw_line_start = 0;
        __s.draw_line_limit = 0;
      }
    }

    {
      pressed := button(s, "Random", *__s.theme.button_theme);
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
      if pressed  {
        for 0 .. 100 {
          array_add(*__s.vectors, 
            Vector2.{
              xx (random_get() % xx __s.window_width), 
              xx (random_get() % xx __s.window_height), 
            });
        }
      }
    }

    aspect := get_desired_aspect_ratio(*__s.theme.color_picker_theme);

    {
      s.y += 0.5 * k;
      label(s, "Fill", *__s.theme.label_theme);
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
      picker := get_rect(s.x, s.y, s.w, 5*k/aspect);
      color_picker_theme := *__s.theme.color_picker_theme;
      applied := color_picker(picker, *__s.secondary_color, color_picker_theme);
      s.y += picker.h;
    }

    {
      s.y += 0.5 * k;
      label(s, "Line", *__s.theme.label_theme);
      s.y += floor(__s.font.character_height * 1.1 + 0.5);
      picker := get_rect(s.x, s.y, s.w, 5*k/aspect);
      color_picker_theme := *__s.theme.color_picker_theme;
      applied := color_picker(picker, *__s.primary_color, color_picker_theme);
      s.y += picker.h;
    }

    end_scrollable_region(region, s.x + s.w, s.y, *__s.scroll_value_dragdrop_region);

  } // end show ui

  Simp.immediate_flush();
  Simp.swap_buffers(__s.window);
  memory_visualizer_per_frame_update();

  sleep_milliseconds(1); 
  if __s.flags & .loop {
    now := current_time_monotonic();
    ms_passed:= to_milliseconds(now - __s.start_time);
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

Triangle :: struct {
  a: Vector2;
  b: Vector2;
  c: Vector2;
};


// adapted from https://github.com/Muzkaw/Ear-clipping-triangulation/blob/master/Ear%20clipping%20triangulation/Triangulation.cpp
triangulate :: (original_points:[]Vector2) -> [..]Triangle {
  triangles: [..]Triangle;
  triangles.allocator = temp;

  points : [..] Vector2;
  points.allocator = temp; 
  array_copy(*points, original_points);

	if(points.count >= 3) {
    ear_found := true ;
		while(points.count >= 0 && ear_found) {
			ear_found = false;
			for idx: 0 .. points.count-3 {
        a := points[idx];
        b := points[idx + 1];
        c := points[idx + 2];
        if determinant(b-a, c-b) > 0 {
          // if the triangle winds in the right direction
          ear_found = true;
          for original_points {
            point_view := array_view(original_points, it_index);
            if is_another_vertex_inside_triangle(c,b,a,point_view) {
              ear_found = false; 
              break;
            }
          }
          if ear_found {
            array_add(*triangles, .{ a, b, c});
            // remove middle point, which is always not connected to anything else
            array_ordered_remove_by_index(*points, idx+1);
            break;
          }
        } // winding
			} // for
		} // while
	} // point count			
  return triangles;
}


// This ends up being the area of a paralellagram 

determinant :: (a:Vector2, b:Vector2) -> float {
  return a.x*b.y - a.y*b.x;
}

is_vertex_inside_triangle :: (a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool {
  ab := b - a;
  bc := c - b;
  ca := a - c;
  return determinant(ab, point-a) < 0 && 
         determinant(bc, point-b) < 0 && 
         determinant(ca, point-c) < 0;
}

is_another_vertex_inside_triangle :: (a:Vector2, b:Vector2, c:Vector2, arr: [] Vector2) -> bool {
  for point: arr {
    if is_vertex_inside_triangle(a, b, c, point) {
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

#import "Math";

String :: #import "String";
System :: #import "System";
#import "Random";

