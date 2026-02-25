package main

import (
	"fmt"
	"sort"
)

func main() {
	const N = 100000
	data := make([]int, N)

	// Fill with pseudo-random values (LCG)
	seed := uint32(42)
	for i := 0; i < N; i++ {
		seed = seed*1103515245 + 12345
		data[i] = int(seed>>16) & 0x7fff
	}

	// Sort
	sort.Ints(data)

	// Verify and checksum
	checksum := int64(0)
	for i := 0; i < N; i++ {
		checksum += int64(data[i])
		if i > 0 && data[i] < data[i-1] {
			fmt.Printf("ERROR: not sorted at index %d\n", i)
			return
		}
	}

	fmt.Printf("sort checksum: %d (N=%d)\n", checksum, N)
}
