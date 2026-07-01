;; Official corpus import.wast — expected: "trailing characters found: `x`"
(component (import "locked-dep=<a:a@1.2.3>x" (func)))
