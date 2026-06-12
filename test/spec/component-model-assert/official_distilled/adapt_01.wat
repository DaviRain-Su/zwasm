;; Official corpus adapt.wast — expected: "memory index out of bounds"
(component
    (import "i" (func $f))
    (core func (canon lower (func $f) (memory 0)))
  )
