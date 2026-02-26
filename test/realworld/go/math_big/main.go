package main

import (
	"fmt"
	"math/big"
)

func factorial(n int64) *big.Int {
	result := big.NewInt(1)
	for i := int64(2); i <= n; i++ {
		result.Mul(result, big.NewInt(i))
	}
	return result
}

func main() {
	// Large factorial
	f20 := factorial(20)
	fmt.Printf("20! = %s\n", f20.String())

	// Big integer addition and comparison
	a := new(big.Int)
	a.SetString("123456789012345678901234567890", 10)
	b := new(big.Int)
	b.SetString("987654321098765432109876543210", 10)

	sum := new(big.Int).Add(a, b)
	diff := new(big.Int).Sub(b, a)
	cmp := a.Cmp(b)

	fmt.Printf("sum: %s\n", sum.String())
	fmt.Printf("diff: %s\n", diff.String())
	fmt.Printf("a < b: %v\n", cmp < 0)

	// Power of 2
	pow := new(big.Int).Exp(big.NewInt(2), big.NewInt(100), nil)
	fmt.Printf("2^100 digits: %d\n", len(pow.String()))
}
