use std::fmt;

struct Matrix {
    rows: usize,
    cols: usize,
    data: Vec<f64>,
}

impl Matrix {
    fn new(rows: usize, cols: usize) -> Self {
        Matrix { rows, cols, data: vec![0.0; rows * cols] }
    }

    fn set(&mut self, r: usize, c: usize, v: f64) {
        self.data[r * self.cols + c] = v;
    }

    fn get(&self, r: usize, c: usize) -> f64 {
        self.data[r * self.cols + c]
    }

    fn multiply(&self, other: &Matrix) -> Matrix {
        assert_eq!(self.cols, other.rows);
        let mut result = Matrix::new(self.rows, other.cols);
        for i in 0..self.rows {
            for j in 0..other.cols {
                let mut sum = 0.0;
                for k in 0..self.cols {
                    sum += self.get(i, k) * other.get(k, j);
                }
                result.set(i, j, sum);
            }
        }
        result
    }

    fn trace(&self) -> f64 {
        let n = self.rows.min(self.cols);
        (0..n).map(|i| self.get(i, i)).sum()
    }
}

impl fmt::Display for Matrix {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Matrix({}x{}) trace={:.2}", self.rows, self.cols, self.trace())
    }
}

fn main() {
    let size = 20;
    let mut a = Matrix::new(size, size);
    let mut b = Matrix::new(size, size);

    // Fill with deterministic values
    for i in 0..size {
        for j in 0..size {
            a.set(i, j, (i * size + j) as f64 * 0.01);
            b.set(i, j, ((size - i) * size + j) as f64 * 0.01);
        }
    }

    let c = a.multiply(&b);

    println!("{}", a);
    println!("{}", b);
    println!("{}", c);
    println!("c[0][0]: {:.4} c[9][9]: {:.4}", c.get(0, 0), c.get(9, 9));
}
