package main

import (
	"encoding/json"
	"fmt"
)

type Record struct {
	ID     int      `json:"id"`
	Name   string   `json:"name"`
	Score  float64  `json:"score"`
	Tags   []string `json:"tags"`
	Active bool     `json:"active"`
}

func main() {
	const N = 1000
	records := make([]Record, N)

	// Build records
	for i := 0; i < N; i++ {
		records[i] = Record{
			ID:     i,
			Name:   fmt.Sprintf("item_%d", i),
			Score:  float64(i) * 1.5,
			Tags:   []string{"tag_a", "tag_b", fmt.Sprintf("tag_%d", i%10)},
			Active: i%2 == 0,
		}
	}

	// Marshal to JSON
	data, err := json.Marshal(records)
	if err != nil {
		fmt.Printf("marshal error: %v\n", err)
		return
	}

	// Unmarshal back
	var decoded []Record
	err = json.Unmarshal(data, &decoded)
	if err != nil {
		fmt.Printf("unmarshal error: %v\n", err)
		return
	}

	// Verify
	if len(decoded) != N {
		fmt.Printf("ERROR: expected %d records, got %d\n", N, len(decoded))
		return
	}
	if decoded[42].Name != "item_42" {
		fmt.Printf("ERROR: expected item_42, got %s\n", decoded[42].Name)
		return
	}

	fmt.Printf("json roundtrip OK: %d records, %d bytes\n", len(decoded), len(data))
}
