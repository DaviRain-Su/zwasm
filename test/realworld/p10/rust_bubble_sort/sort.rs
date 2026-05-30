#![no_std]
#![no_main]
// Real algorithm on the shadow stack: bubble-sort a local [i32; 8] then
// return the 4th-smallest. black_box on the input forces the sort to run
// at runtime (no const-fold), exercising nested loops + array read/write
// (i32.load/store) + bounds checks + swaps through real rustc codegen.
// input [5,2,8,1,9,3,7,4] -> sorted [1,2,3,4,5,7,8,9]; a[3] = 4.
#[no_mangle]
pub extern "C" fn test() -> i32 {
    let mut a: [i32; 8] = core::hint::black_box([5, 2, 8, 1, 9, 3, 7, 4]);
    let n = a.len();
    let mut i = 0;
    while i < n {
        let mut j = 0;
        while j + 1 < n {
            if a[j] > a[j + 1] {
                a.swap(j, j + 1);
            }
            j += 1;
        }
        i += 1;
    }
    a[3]
}
#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}
