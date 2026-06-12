;; Official corpus import.wast — expected: "url cannot contain `<`"
(component (import "url=<<>" (func)))
