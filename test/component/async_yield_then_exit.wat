;; WASI-0.3 / CM-async fixture (D-335 unit D-ηB, ADR-0188): the task entry
;; returns YIELD (1), so the stackless loop MUST re-enter the guest callback;
;; the callback returns EXIT (0), ending the loop after exactly one re-entry.
;; Exercises driveCallbackLoop's YIELD branch + the P3 runner's invokeCallback
;; seam END-TO-END through a real Instance (the immediate-EXIT fixture only
;; covered the loop-never-runs path). A miswired callback would spin on YIELD.
(component
  (core module $m
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0) ;; 0 = EXIT
    (func (export "run") (result i32) i32.const 1)) ;; 1 = YIELD
  (core instance $i (instantiate $m))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
