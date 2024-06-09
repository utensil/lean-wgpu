import Lake
open Lake DSL

package Wgpu

require alloy from git "https://github.com/tydeu/lean4-alloy/" @ "master"

section Platform
  inductive Arch where
  | x86_64
  | arm64
  deriving Inhabited, BEq, Repr

  def systemCommand (cmd : String) (args : Array String): IO String := do
    let out ← IO.Process.output {cmd, args, stdin := .null}
    return out.stdout.trim

  -- Inspired by from https://github.com/lean-dojo/LeanCopilot/blob/main/lakefile.lean
  def getArch? : IO (Option String) := systemCommand "uname" #["-m"]

  def getArch : Arch :=
    match run_io getArch? with
    | "arm64" => Arch.arm64
    | "aarch64" => Arch.arm64
    | "x86_64" => Arch.x86_64
    | _ => panic! "Unable to determine architecture (you might not have the command `uname` installed or in PATH.)"

  inductive OS where | windows | linux | macos
  deriving Inhabited, BEq, Repr

  open System in
  def getOS : OS :=
    if Platform.isWindows then .windows
    else if Platform.isOSX then .macos
    else .linux
end Platform

module_data alloy.c.o.export : BuildJob FilePath
module_data alloy.c.o.noexport : BuildJob FilePath


section Glfw
  /-! GLFW is a cross-platform library for opening a window. -/
  def glfw_path : String :=
    match (getOS, getArch) with
    | (.macos, _) => (run_io (systemCommand "brew" #["--prefix", "glfw"])) -- returns for example "/opt/homebrew/opt/glfw"
    | _ => panic! "Unsupported arch/os combination"
  def glfw_include_path : String := glfw_path ++ "/include"
  def glfw_library_path : String := glfw_path ++ "/lib"
  #eval glfw_include_path

  /-- I guess long-term we'll extract Glfw bindings into its own repo? -/
  lean_lib Glfw where
    moreLeancArgs := #[
      "-I", glfw_include_path,
      "-fPIC"
    ]
    precompileModules := true
    nativeFacets := fun shouldExport =>
      if shouldExport then #[Module.oExportFacet, `alloy.c.o.export]
      else #[Module.oNoExportFacet, `alloy.c.o.noexport]
end Glfw


section wgpu_native
  -- TODO: download wgpu automatically.
  -- Download manually from: https://github.com/gfx-rs/wgpu-native/releases
  def wgpu_native_dir :=
    let s :=
      match (getOS, getArch) with
      | (.macos, .arm64) => "wgpu-macos-aarch64"
      | (.linux, .x86_64) => "wgpu-linux-x86_64"
      | _ => panic! "Unsupported arch/os combination"
    s!"libs/{s}-debug"

  extern_lib wgpu_native pkg :=
    inputFile <| pkg.dir / wgpu_native_dir / nameToStaticLib "wgpu_native"
end wgpu_native

lean_lib Wgpu where
  moreLeancArgs := #[
    "-fPIC"
  ]
  weakLeancArgs := #[
    "-I", glfw_include_path,
    "-I", __dir__ / wgpu_native_dir |>.toString
  ]
  precompileModules := true
  nativeFacets := fun shouldExport =>
    if shouldExport then #[Module.oExportFacet, `alloy.c.o.export]
    else #[Module.oNoExportFacet, `alloy.c.o.noexport]

@[default_target]
lean_exe helloworld where
  moreLinkArgs :=
    if getOS == .macos
      then #[
        s!"-L{glfw_library_path}", "-lglfw",
        "-framework", "Metal", -- for wgpu
        "-framework", "QuartzCore", -- for wgpu
        "-framework", "CoreFoundation" -- for wgpu
      ]
      else #["-lglfw"]
  root := `Main
