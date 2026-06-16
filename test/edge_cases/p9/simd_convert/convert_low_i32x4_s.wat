(module (func (export "test") (result i32)
  (i32.trunc_f64_s (f64x2.extract_lane 0 (f64x2.convert_low_i32x4_s (i32x4.splat (i32.const 11)))))))