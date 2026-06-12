;; Official corpus func.wast — expected: "function parameter name `FOO` conflicts with previous parameter name `foo`"
(component
    (type (func (param "foo" string) (param "FOO" u32)))
  )
