use std::collections::HashMap;

fn main() {
    let mut map: HashMap<String, Vec<i32>> = HashMap::new();

    // Insert entries with vectors
    for i in 0..200 {
        let key = format!("group_{}", i % 20);
        map.entry(key).or_insert_with(Vec::new).push(i * i % 997);
    }

    // Compute stats per group
    let mut total_items = 0usize;
    let mut grand_sum = 0i64;
    let mut max_group_size = 0usize;

    for (_, values) in &map {
        total_items += values.len();
        grand_sum += values.iter().map(|&v| v as i64).sum::<i64>();
        if values.len() > max_group_size {
            max_group_size = values.len();
        }
    }

    // Remove groups with even index
    let keys_to_remove: Vec<String> = map.keys()
        .filter(|k| {
            let num: usize = k.strip_prefix("group_")
                .and_then(|s| s.parse().ok())
                .unwrap_or(0);
            num % 2 == 0
        })
        .cloned()
        .collect();

    for k in &keys_to_remove {
        map.remove(k);
    }

    println!("groups: 20 items: {} sum: {} max_size: {} remaining: {}",
             total_items, grand_sum, max_group_size, map.len());
}
