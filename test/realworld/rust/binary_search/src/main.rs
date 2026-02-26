fn binary_search(arr: &[i32], target: i32) -> Option<usize> {
    let mut lo = 0usize;
    let mut hi = arr.len();
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        match arr[mid].cmp(&target) {
            std::cmp::Ordering::Equal => return Some(mid),
            std::cmp::Ordering::Less => lo = mid + 1,
            std::cmp::Ordering::Greater => hi = mid,
        }
    }
    None
}

fn lower_bound(arr: &[i32], target: i32) -> usize {
    let mut lo = 0usize;
    let mut hi = arr.len();
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if arr[mid] < target { lo = mid + 1; } else { hi = mid; }
    }
    lo
}

fn main() {
    // Create sorted array with duplicates
    let arr: Vec<i32> = (0..10000).map(|i| i / 3).collect();

    // Search for various targets
    let mut found = 0;
    let mut not_found = 0;
    for target in 0..4000 {
        if binary_search(&arr, target).is_some() {
            found += 1;
        } else {
            not_found += 1;
        }
    }

    // Lower bound tests
    let lb_100 = lower_bound(&arr, 100);
    let lb_0 = lower_bound(&arr, 0);
    let lb_max = lower_bound(&arr, 9999);

    println!("found: {} not_found: {}", found, not_found);
    println!("lb(100): {} lb(0): {} lb(9999): {}", lb_100, lb_0, lb_max);
    println!("arr[lb_100]: {} arr_len: {}", arr[lb_100], arr.len());
}
