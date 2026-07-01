;; Official corpus definedtypes.wast — expected: "variant case name `x` conflicts with previous case name `x`"
(component (type (variant (case "x" s64) (case "x" s64))))
