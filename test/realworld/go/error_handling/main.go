package main

import (
	"errors"
	"fmt"
	"strconv"
)

type ParseError struct {
	Input string
	Err   error
}

func (e *ParseError) Error() string {
	return fmt.Sprintf("parse %q: %v", e.Input, e.Err)
}

func (e *ParseError) Unwrap() error { return e.Err }

var ErrOutOfRange = errors.New("value out of range")

func parseAndValidate(s string, min, max int) (int, error) {
	v, err := strconv.Atoi(s)
	if err != nil {
		return 0, &ParseError{Input: s, Err: err}
	}
	if v < min || v > max {
		return 0, &ParseError{Input: s, Err: fmt.Errorf("%w: %d not in [%d,%d]", ErrOutOfRange, v, min, max)}
	}
	return v, nil
}

func main() {
	inputs := []string{"42", "999", "-1", "abc", "100", "0", "50"}
	var sum int
	var errCount int

	for _, input := range inputs {
		v, err := parseAndValidate(input, 0, 100)
		if err != nil {
			errCount++
			var pe *ParseError
			if errors.As(err, &pe) {
				if errors.Is(err, ErrOutOfRange) {
					fmt.Printf("range error: %s\n", pe.Error())
				} else {
					fmt.Printf("parse error: %s\n", pe.Error())
				}
			}
		} else {
			sum += v
		}
	}

	fmt.Printf("sum: %d errors: %d\n", sum, errCount)
}
