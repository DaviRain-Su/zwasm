;; Official corpus definedtypes.wast — expected: "flag name `X` conflicts with previous flag name `x`"
(component (type (flags "x" "y" "X")))
