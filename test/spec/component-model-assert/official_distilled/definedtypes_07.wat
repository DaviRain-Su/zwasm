;; Official corpus definedtypes.wast — expected: "record field name `A-b-C-d` conflicts with previous field name `a-B-c-D`"
(component (type (record (field "a-B-c-D" string) (field "A-b-C-d" u8))))
