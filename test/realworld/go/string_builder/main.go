package main

import (
	"fmt"
	"strings"
)

func main() {
	var b strings.Builder
	for i := 0; i < 1000; i++ {
		b.WriteString(fmt.Sprintf("item_%d,", i))
	}
	result := b.String()
	count := strings.Count(result, ",")
	hasPrefix := strings.HasPrefix(result, "item_0,")
	hasSuffix := strings.HasSuffix(result, "item_999,")
	fmt.Printf("length: %d commas: %d prefix: %v suffix: %v\n",
		len(result), count, hasPrefix, hasSuffix)
}
