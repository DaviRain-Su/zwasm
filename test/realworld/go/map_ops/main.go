package main

import (
	"fmt"
	"sort"
)

func main() {
	m := make(map[string]int)

	// Insert 100 entries (smaller to avoid stack overflow)
	for i := 0; i < 100; i++ {
		key := fmt.Sprintf("key_%03d", i)
		m[key] = i * i
	}

	// Lookup
	found := 0
	for i := 0; i < 100; i += 3 {
		key := fmt.Sprintf("key_%03d", i)
		if _, ok := m[key]; ok {
			found++
		}
	}

	// Collect and sort keys
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	// Delete half
	for i := 0; i < 100; i += 2 {
		key := fmt.Sprintf("key_%03d", i)
		delete(m, key)
	}

	fmt.Printf("total: 100 found: %d sorted_first: %s remaining: %d\n",
		found, keys[0], len(m))
}
