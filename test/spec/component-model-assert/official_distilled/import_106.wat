;; Official corpus import.wast — expected: "not a valid extern name"
(component
    (import "relative-url=<>" (func))
    (import "relative-url=<a>" (func))
    (import "relative-url=<a>,integrity=<sha256-a>" (func))
  )
