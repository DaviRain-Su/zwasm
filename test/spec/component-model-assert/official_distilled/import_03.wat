;; Official corpus import.wast — expected: "type index out of bounds"
(component
    (import "a" (func (type 100)))
  )
