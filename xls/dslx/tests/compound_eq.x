// Copyright 2021 The XLS Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// The leaf values have a tiny range so that 1000 tests can find a
// counterexample if the equality check is broken.
type TestBlob = (s2[2], (u2, u1), bool);

fn main() -> TestBlob {
  // This test would be more meaningful if it used a compound equality,
  // but that is currently blocked by https://github.com/google/xls/issues/421
  ([s2:0,s2:3], (u2:1,u1:0), true)
 }

// Manually expand a test blob into its leaf components to check equality.
fn blob_eq(x: TestBlob, y:TestBlob) -> bool {
  let zero = u32:0;
  let one  = u32:1;
  match (x,y) {
    ((x_arr, (x_tup1, x_tup2), x_bool),
     (y_arr, (y_tup1, y_tup2), y_bool)) =>
       x_arr[zero] == y_arr[zero] && x_arr[one] == y_arr[one] &&
       x_tup1 == y_tup1 && x_tup2 == y_tup2 &&
       x_bool == y_bool
  }
}

// Check the equality of TestBlob arrays element-by-element two different ways:
// 1. Relying on built-in support for tuple equality.
// 2. Manually expanding the TestBlob and checking the leaf values directly.
fn eq_by_element(x: TestBlob[3], y: TestBlob[3]) -> bool {
  for (i, eq):(u32, bool) in range (u32:0, u32:3) {
    eq && x[i] == y[i] && blob_eq(y[i], x[i])
  }(true)
}

// The default 1000 tests aren't enough to generate a counterexample
// when eq_by_element has a bug (like not checking every element).
#![quickcheck(test_count=100000)]
fn prop_consistent_eq(x: TestBlob[3], y: TestBlob[3]) -> bool {
  x == x && eq_by_element(x,x) && y == y && eq_by_element(y,y) &&
  x == y == eq_by_element(x,y)
}


