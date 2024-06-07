import Alloy.C
open scoped Alloy.C

alloy c section
  -- #include <stdio.h>
  #include <lean/lean.h>
  #include <wgpu.h>
  #include <webgpu.h>
end

alloy c extern
def test (x : UInt32) : IO UInt32 := {
  WGPUInstance *inst = NULL;
  return lean_io_result_mk_ok(lean_box(sizeof(WGPUInstance)));
}

alloy c extern
def helloworld (n : UInt32) : IO UInt64 := {
  -- We create a descriptor
  WGPUInstanceDescriptor desc = {};
  desc.nextInChain = NULL;

  -- WGPUInstance inst = wgpuCreateInstance(&desc);
  -- if (!inst) {
  --   return lean_io_result_mk_error(lean_box(1));
  -- }

  return lean_io_result_mk_ok(lean_box(0));
}
