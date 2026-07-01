;; Official corpus definedtypes.wast — expected: "enum tag name `X` conflicts with previous tag name `x`"
(component (type (enum "x" "y" "X")))
