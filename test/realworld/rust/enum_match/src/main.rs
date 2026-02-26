use std::fmt;

#[derive(Debug)]
enum Shape {
    Circle(f64),
    Rectangle(f64, f64),
    Triangle(f64, f64, f64),
}

impl Shape {
    fn area(&self) -> f64 {
        match self {
            Shape::Circle(r) => std::f64::consts::PI * r * r,
            Shape::Rectangle(w, h) => w * h,
            Shape::Triangle(a, b, c) => {
                let s = (a + b + c) / 2.0;
                (s * (s - a) * (s - b) * (s - c)).sqrt()
            }
        }
    }

    fn perimeter(&self) -> f64 {
        match self {
            Shape::Circle(r) => 2.0 * std::f64::consts::PI * r,
            Shape::Rectangle(w, h) => 2.0 * (w + h),
            Shape::Triangle(a, b, c) => a + b + c,
        }
    }
}

impl fmt::Display for Shape {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Shape::Circle(r) => write!(f, "Circle(r={})", r),
            Shape::Rectangle(w, h) => write!(f, "Rect({}x{})", w, h),
            Shape::Triangle(a, b, c) => write!(f, "Tri({},{},{})", a, b, c),
        }
    }
}

fn main() {
    let shapes: Vec<Shape> = (0..300).map(|i| {
        match i % 3 {
            0 => Shape::Circle((i as f64) * 0.5 + 1.0),
            1 => Shape::Rectangle((i as f64) + 1.0, (i as f64) * 0.5 + 1.0),
            _ => Shape::Triangle(3.0 + (i as f64) * 0.1, 4.0 + (i as f64) * 0.1, 5.0 + (i as f64) * 0.1),
        }
    }).collect();

    let total_area: f64 = shapes.iter().map(|s| s.area()).sum();
    let total_perim: f64 = shapes.iter().map(|s| s.perimeter()).sum();
    let circles = shapes.iter().filter(|s| matches!(s, Shape::Circle(_))).count();

    println!("shapes: {} circles: {}", shapes.len(), circles);
    println!("total_area: {:.2} total_perimeter: {:.2}", total_area, total_perim);
    println!("first: {} last: {}", shapes[0], shapes[299]);
}
