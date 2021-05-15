// Copyright 2020 The XLS Authors
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

// DSLX standard library routines.

// Returns unsigned mul of x (N bits) and y (M bits) as an N+M bit value.
pub fn umul<N: u32, M: u32, R: u32 = N + M>(x: uN[N], y: uN[M]) -> uN[R] {
  (x as uN[R]) * (y as uN[R])
}

// Returns signed mul of x (N bits) and y (M bits) as an N+M bit value.
pub fn smul<N: u32, M: u32, R: u32 = N + M>(x: sN[N], y: sN[M]) -> sN[R] {
  (x as sN[R]) * (y as sN[R])
}

#![test]
fn smul_test() {
  let _ = assert_eq(s6:4, smul(s3:2, s3:2));
  let _ = assert_eq(s4:0b1111, smul(s2:0b11, s2:0b01));
  ()
}

#![test]
fn umul_test() {
  let _ = assert_eq(u6:4, umul(u3:2, u3:2));
  let _ = assert_eq(u4:0b0011, umul(u2:0b11, u2:0b01));
  let _ = assert_eq(u4:0b1001, umul(u2:0b11, u2:0b11));
  ()
}

// Calculate x / y one bit at a time. This is an alternative to using
// the division operator '/' which may not synthesize nicely.
pub fn iterative_div<N: u32, DN: u32 = N * u32:2>(x: uN[N], y: uN[N]) -> uN[N] {

  let init_shift_amount = ((N as uN[N])-uN[N]:1);
  let x = x as uN[DN];

  let (_, _, _, div_result) =
        for(idx, (shifted_y, shifted_index_bit, running_product, running_result)): (u32, (uN[DN], uN[N], uN[DN], uN[N]))
        in range(u32:0, N) {

    // Increment running_result by current power of 2
    // if the prodcut running_result * y < x.
    let inc_running_result = running_result | shifted_index_bit;
    let inc_running_product = running_product + shifted_y;
    let (running_result, running_product) =
            (inc_running_result, inc_running_product)
        if (inc_running_product <= x)
        else (running_result, running_product);

    // Shift to next (lower) power of 2.
    let shifted_y = shifted_y >> uN[N]:1;
    let shifted_index_bit = shifted_index_bit >> uN[N]:1;

    (shifted_y, shifted_index_bit, running_product, running_result)
  } (( (y as uN[DN]) << (init_shift_amount as uN[DN]),
       uN[N]:1 << init_shift_amount,
       uN[DN]:0,
       uN[N]:0));

  div_result
}

#![test]
fn iterative_div_test () {
  // Power of 2.
  let _ = assert_eq(u4:0, iterative_div(u4:8, u4:15));
  let _ = assert_eq(u4:1, iterative_div(u4:8, u4:8));
  let _ = assert_eq(u4:2, iterative_div(u4:8, u4:4));
  let _ = assert_eq(u4:4, iterative_div(u4:8, u4:2));
  let _ = assert_eq(u4:8, iterative_div(u4:8, u4:1));
  let _ = assert_eq(u4:8 / u4:0, iterative_div(u4:8, u4:0));
  let _ = assert_eq(u4:15, iterative_div(u4:8, u4:0));

  // Non-powers-of-2.
  let _ = assert_eq(u32:6, iterative_div(u32:18, u32:3));
  let _ = assert_eq(u32:6, iterative_div(u32:36, u32:6));
  let _ = assert_eq(u32:6, iterative_div(u32:48, u32:8));
  let _ = assert_eq(u32:20, iterative_div(u32:900, u32:45));

  // Results w/ remainder.
  let _ = assert_eq(u32:6, iterative_div(u32:20, u32:3));
  let _ = assert_eq(u32:6, iterative_div(u32:41, u32:6));
  let _ = assert_eq(u32:6, iterative_div(u32:55, u32:8));
  let _ = assert_eq(u32:20, iterative_div(u32:944, u32:45));
  ()
}

// Returns the value of x-1 with saturation at 0.
pub fn bounded_minus_1<N: u32>(x: uN[N]) -> uN[N] {
  x if x == uN[N]:0 else x-uN[N]:1
}

// Extracts the LSb (least significant bit) from the value `x` and returns it.
pub fn lsb<N: u32>(x: uN[N]) -> u1 {
  x as u1
}

#![test]
fn lsb_test() {
  let _ = assert_eq(u1:0, lsb(u2:0b00));
  let _ = assert_eq(u1:1, lsb(u2:0b01));
  let _ = assert_eq(u1:1, lsb(u2:0b11));
  let _ = assert_eq(u1:0, lsb(u2:0b10));
  ()
}

// Returns the absolute value of x as a signed number.
pub fn abs<BITS: u32>(x: sN[BITS]) -> sN[BITS] {
  -x if x < sN[BITS]:0 else x
}

// Converts an array of N bools to a bits[N] value.
pub fn convert_to_bits<N: u32>(x: bool[N]) -> uN[N] {
  for (i, accum): (u32, uN[N]) in range(u32:0, N) {
   accum | (x[i] as uN[N]) << ((N-i-u32:1) as uN[N])
  }(uN[N]:0)
}

#![test]
fn convert_to_bits_test() {
  let _ = assert_eq(u3:0b010, convert_to_bits(bool[3]:[false, true, false]));
  let _ = assert_eq(u3:0b011, convert_to_bits(bool[3]:[false, true, true]));
  ()
}

// Returns (found, index) given array and the element to find within the array.
//
// Note that when found is false, the index is 0 -- 0 is provided instead of a
// value like -1 to prevent out-of-bounds accesses from occurring if the index
// is used in a match expression (which will eagerly evaluate all of its arms),
// to prevent it from creating an error at simulation time if the value is
// ultimately discarded from the unselected match arm.
pub fn find_index<BITS: u32, ELEMS: u32>(
    array: uN[BITS][ELEMS], x: uN[BITS]) -> (bool, u32) {
  // Compute all the positions that are equal to our target.
  let bools: bool[ELEMS] = for (i, accum): (u32, bool[ELEMS]) in range(u32:0, ELEMS) {
    update(accum, i, array[i] == x)
  }((bool[ELEMS]:[false, ...]));

  let x: uN[ELEMS] = convert_to_bits(bools);
  let index = clz(x);
  let found: bool = or_reduce(x);
  (found, index as u32 if found else u32:0)
}

#![test]
fn find_index_test() {
  let haystack = u3[4]:[0b001, 0b010, 0b100, 0b111];
  let _ = assert_eq((true, u32:1), find_index(haystack, u3:0b010));
  let _ = assert_eq((true, u32:3), find_index(haystack, u3:0b111));
  let _ = assert_eq((false, u32:0), find_index(haystack, u3:0b000));
  ()
}

// Concatenates 3 values of arbitrary bitwidths to a single value.
pub fn concat3<X: u32, Y: u32, Z: u32, R: u32 = X + Y + Z>(
    x: bits[X], y: bits[Y], z: bits[Z]) -> bits[R] {
  x ++ y ++ z
}

#![test]
fn concat3_test() {
  let _ = assert_eq(u12:0b111000110010,
                    concat3(u6:0b111000, u4:0b1100, u2:0b10));
  ()
}

// Returns the ceiling of (x divided by y).
pub fn ceil_div<N: u32>(x: uN[N], y: uN[N]) -> uN[N] {
  let usual = (x - uN[N]:1) / y + uN[N]:1;
  usual if x > uN[N]:0 else uN[N]:0
}

#![test]
fn ceil_div_test() {
  let _ = assert_eq(ceil_div(u32:6, u32:2), u32:3);
  let _ = assert_eq(ceil_div(u32:5, u32:2), u32:3);
  let _ = assert_eq(ceil_div(u32:4, u32:2), u32:2);
  let _ = assert_eq(ceil_div(u32:3, u32:2), u32:2);
  let _ = assert_eq(ceil_div(u32:2, u32:2), u32:1);
  let _ = assert_eq(ceil_div(u32:1, u32:2), u32:1);
  let _ = assert_eq(ceil_div(u32:0, u32:2), u32:0);

  let _ = assert_eq(ceil_div(u8:6, u8:3), u8:2);
  let _ = assert_eq(ceil_div(u8:5, u8:3), u8:2);
  let _ = assert_eq(ceil_div(u8:4, u8:3), u8:2);
  let _ = assert_eq(ceil_div(u8:3, u8:3), u8:1);
  let _ = assert_eq(ceil_div(u8:2, u8:3), u8:1);
  let _ = assert_eq(ceil_div(u8:1, u8:3), u8:1);
  let _ = assert_eq(ceil_div(u8:0, u8:3), u8:0);

  _
}

pub fn round_up_to_nearest(x: u32, y: u32) -> u32 {
  (ceil_div(x, y) * y) as u32
}

#![test]
fn round_up_to_nearest_test() {
  let _ = assert_eq(u32:4, round_up_to_nearest(u32:3, u32:2));
  let _ = assert_eq(u32:4, round_up_to_nearest(u32:4, u32:2));
  _
}

pub fn rrot<N: u32>(x: bits[N], y: bits[N]) -> bits[N] {
  (x >> y) | (x << ((N as bits[N]) - y))
}

#![test]
fn rrot_test() {
  let _ = assert_eq(bits[3]:0b101, rrot(bits[3]:0b011, bits[3]:1));
  let _ = assert_eq(bits[3]:0b011, rrot(bits[3]:0b110, bits[3]:1));
  _
}

// Returns the maximum of two signed integers.
pub fn smax<N: u32>(x: sN[N], y: sN[N]) -> sN[N] {
  x if x > y else y
}

#![test]
fn smax_test() {
  let _ = assert_eq(s32:1,  smax(s32:1,  s32:0));
  let _ = assert_eq(s32:1,  smax(s32:1,  s32:1));
  let _ = assert_eq(s32:3,  smax(s32:3,  s32:2));
  let _ = assert_eq(s32:0,  smax(s32:-1, s32:0));
  let _ = assert_eq(s32:-1, smax(s32:-1, s32:-1));
  let _ = assert_eq(s32:-2, smax(s32:-2, s32:-3));
  let _ = assert_eq(s32:2,  smax(s32:-3, s32:2));
  let _ = assert_eq(s32:2,  smax(s32:-1, s32:2));
  ()
}

// Returns the maximum of two unsigned integers.
pub fn umax<N: u32>(x: uN[N], y: uN[N]) -> uN[N] {
  x if x > y else y
}

#![test]
fn umax_test() {
  let _ = assert_eq(u1:1, umax(u1:1, u1:0));
  let _ = assert_eq(u1:1, umax(u1:1, u1:1));
  let _ = assert_eq(u2:3, umax(u2:3, u2:2));
  ()
}

// Returns the minimum of two unsigned integers.
pub fn umin<N: u32>(x: uN[N], y: uN[N]) -> uN[N] {
  x if x < y else y
}

#![test]
fn umin_test() {
  let _ = assert_eq(u1:0, umin(u1:1, u1:0));
  let _ = assert_eq(u1:1, umin(u1:1, u1:1));
  let _ = assert_eq(u2:2, umin(u2:3, u2:2));
  ()
}

// Returns the minimum of two signed integers.
pub fn smin<N: u32>(x: sN[N], y: sN[N]) -> sN[N] {
  x if x < y else y
}

#![test]
fn smin_test() {
  let _ = assert_eq(s32:0,  smin(s32:1,  s32:0));
  let _ = assert_eq(s32:1,  smin(s32:1,  s32:1));
  let _ = assert_eq(s32:2,  smin(s32:3,  s32:2));
  let _ = assert_eq(s32:-1, smin(s32:-1, s32:0));
  let _ = assert_eq(s32:-1, smin(s32:-1, s32:-1));
  let _ = assert_eq(s32:-3, smin(s32:-2, s32:-3));
  let _ = assert_eq(s32:-3, smin(s32:-3, s32:2));
  let _ = assert_eq(s32:-1, smin(s32:-1, s32:2));
  ()
}

// Return 'x' clammped to be within the bounds [min_inc, max_inc].
pub fn sclamp(x:s32, min_inc:s32, max_inc:s32) -> s32 {
  smax(min_inc, smin(max_inc, x))
}

#![test]
fn sclamp_test() {
  let _ = assert_eq(sclamp(s32:5, s32:0, s32:10), s32:5);
  let _ = assert_eq(sclamp(s32:-5, s32:0, s32:10), s32:0);
  let _ = assert_eq(sclamp(s32:15, s32:0, s32:10), s32:10);
  let _ = assert_eq(sclamp(s32:0, s32:0, s32:10), s32:0);
  let _ = assert_eq(sclamp(s32:10, s32:0, s32:10), s32:10);
  ()
}

// Returns `ceiling(log2(x))`, with one exception:
//
// When x=0, this function differs from the true mathematical function:
// clog2(0) = 0
// ceiling(log2(0)) = -infinity
//
// This function is frequently used to calculate the number of bits required to
// represent `x` possibilities. With this interpretation, it is sensible
// to define clog2(0) = 0.
//
// Example: clog2(7) = 3
pub fn clog2<N: u32>(x: bits[N]) -> bits[N] {
  (N as bits[N]) - clz(x-bits[N]:1) if x >= bits[N]:1 else bits[N]:0
}

#![test]
fn clog2_test() {
  let _ = assert_eq(u32:0, clog2(u32:0));
  let _ = assert_eq(u32:0, clog2(u32:1));
  let _ = assert_eq(u32:1, clog2(u32:2));
  let _ = assert_eq(u32:2, clog2(u32:3));
  let _ = assert_eq(u32:2, clog2(u32:4));
  let _ = assert_eq(u32:3, clog2(u32:5));
  let _ = assert_eq(u32:3, clog2(u32:6));
  let _ = assert_eq(u32:3, clog2(u32:7));
  let _ = assert_eq(u32:3, clog2(u32:8));
  let _ = assert_eq(u32:4, clog2(u32:9));
  ()
}

// Returns true when x is a non-zero power-of-two.
pub fn is_pow2<N: u32>(x: uN[N]) -> bool {
  x > uN[N]:0 && (x & (x - uN[N]:1) == uN[N]:0)
}

#![test]
fn is_pow2_test() {
  let _ = assert_eq(is_pow2(u32: 0), false);
  let _ = assert_eq(is_pow2(u32: 1), true);
  let _ = assert_eq(is_pow2(u32: 2), true);
  let _ = assert_eq(is_pow2(u32: 3), false);
  let _ = assert_eq(is_pow2(u32: 4), true);
  let _ = assert_eq(is_pow2(u32: 5), false);
  let _ = assert_eq(is_pow2(u32: 6), false);
  let _ = assert_eq(is_pow2(u32: 7), false);
  let _ = assert_eq(is_pow2(u32: 8), true);

  // Test parametric bitwidth.
  let _ = assert_eq(is_pow2(u8: 0), false);
  let _ = assert_eq(is_pow2(u8: 1), true);
  let _ = assert_eq(is_pow2(u8: 2), true);
  let _ = assert_eq(is_pow2(u8: 3), false);
  let _ = assert_eq(is_pow2(u8: 4), true);
  let _ = assert_eq(is_pow2(u8: 5), false);
  let _ = assert_eq(is_pow2(u8: 6), false);
  let _ = assert_eq(is_pow2(u8: 7), false);
  let _ = assert_eq(is_pow2(u8: 8), true);

  ()
}

// Returns x % y where y must be a non-zero power-of-two.
pub fn mod_pow2<N: u32>(x: bits[N], y: bits[N]) -> bits[N] {
  // TODO(leary): 2020-06-11 Add assertion y is a power of two and non-zero.
  x & (y-bits[N]:1)
}

#![test]
fn mod_pow2_test() {
  let _ = assert_eq(u32:1, mod_pow2(u32:5, u32:4));
  let _ = assert_eq(u32:0, mod_pow2(u32:4, u32:4));
  let _ = assert_eq(u32:3, mod_pow2(u32:3, u32:4));
  ()
}

// Returns x / y where y must be a non-zero power-of-two.
pub fn div_pow2<N: u32>(x: bits[N], y: bits[N]) -> bits[N] {
  // TODO(leary): 2020-06-11 Add assertion y is a power of two and non-zero.
  x >> clog2(y)
}

#![test]
fn div_pow2_test() {
  let _ = assert_eq(u32:1, div_pow2(u32:5, u32:4));
  let _ = assert_eq(u32:1, div_pow2(u32:4, u32:4));
  let _ = assert_eq(u32:0, div_pow2(u32:3, u32:4));
  ()
}

// Returns a value with X bits set (of type bits[X]).
pub fn mask_bits<X: u32>() -> bits[X] {
  !bits[X]:0
}

#![test]
fn mask_bits_test() {
  let _ = assert_eq(u8:0xff, mask_bits<u32:8>());
  let _ = assert_eq(u13:0x1fff, mask_bits<u32:13>());
  ()
}
