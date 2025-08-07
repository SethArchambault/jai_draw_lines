#run {
  workspace := compiler_create_workspace();
  options := get_build_options();
  options.output_path = "run/";
  options.output_executable_name = "draw_shape";
  set_build_options(options, workspace);
  compiler_begin_intercept(workspace);
  set_build_options_dc(.{ do_output= false });
  add_build_file("src/main.jai", workspace);
  while true {
    message := compiler_wait_for_message();
    if message.kind == {
      case .ERROR; { exit(1); }
      case .COMPLETE; { break; }
    }
  }
  compiler_end_intercept(workspace);
  run_command("run/draw_shape");
}
#import "Basic";
#import "Compiler";
#import "Process";
