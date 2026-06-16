(module (func (export "test") (result i32)
  (i32.trunc_f32_s (f32x4.extract_lane 0 (f32x4.convert_i32x4_s (i32x4.splat (i32.const 7)))))))