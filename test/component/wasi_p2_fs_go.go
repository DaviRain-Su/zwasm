package main

import (
	"fmt"
	"os"
)

func fail(step string, err error) {
	fmt.Println("FAIL", step, err)
}

func main() {
	if err := os.Mkdir("/work/sub", 0o755); err != nil {
		fail("mkdir", err)
		return
	}
	if err := os.WriteFile("/work/sub/a.txt", []byte("DATA42"), 0o644); err != nil {
		fail("write", err)
		return
	}
	st, err := os.Stat("/work/sub/a.txt")
	if err != nil {
		fail("stat", err)
		return
	}
	if st.Size() != 6 {
		fail("stat-size", nil)
		return
	}
	if err := os.Rename("/work/sub/a.txt", "/work/sub/b.txt"); err != nil {
		fail("rename", err)
		return
	}
	entries, err := os.ReadDir("/work/sub")
	if err != nil {
		fail("readdir", err)
		return
	}
	if len(entries) != 1 {
		fail("readdir-count", nil)
		return
	}
	if err := os.Remove("/work/sub/" + entries[0].Name()); err != nil {
		fail("remove-file", err)
		return
	}
	if err := os.Remove("/work/sub"); err != nil {
		fail("remove-dir", err)
		return
	}
	fmt.Println("FS-OK", entries[0].Name())
}
