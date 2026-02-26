fn main() {
    let data: Vec<i32> = (0..1000).collect();

    // Chain of iterator operations
    let result: Vec<i32> = data.iter()
        .filter(|&&x| x % 3 == 0)
        .map(|&x| x * x)
        .take(100)
        .collect();

    let sum: i64 = result.iter().map(|&x| x as i64).sum();
    let max = result.iter().max().unwrap_or(&0);
    let min = result.iter().min().unwrap_or(&0);

    // Zip and fold
    let pairs: i64 = data.iter()
        .zip(data.iter().skip(1))
        .map(|(&a, &b)| (a as i64) * (b as i64))
        .take(500)
        .fold(0i64, |acc, x| acc.wrapping_add(x));

    println!("count: {} sum: {} min: {} max: {}", result.len(), sum, min, max);
    println!("pairs_fold: {}", pairs);
}
