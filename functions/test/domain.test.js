const {test} = require('node:test');
const assert = require('node:assert/strict');
const {listingInput, canReserve} = require('../domain');
const now = 1700000000000;
const valid = {title: 'Lunch box', description: 'Rice and vegetables', address: '1 Test Street',
  dietary: 'Contains soy', category: 'Meals', priceCents: 800, originalPriceCents: 1500,
  stock: 2, pickupStart: now + 3600000, pickupEnd: now + 7200000};
test('listing prices use integer cents; pickup and food details are required', () => {
  assert.equal(listingInput(valid, now).priceCents, 800);
  for (const update of [{priceCents: NaN}, {priceCents: 8.5}, {stock: -1}, {address: ''},
    {dietary: ''}, {originalPriceCents: 700}, {pickupStart: now - 1}, {pickupEnd: now + 1},
    {category: 'invalid'}, {pickupEnd: now + 31 * 86400000}]) {
    assert.throws(() => listingInput({...valid, ...update}, now));
  }
});
test('reservation rejects sold out, expired, paused and invalid quantities', () => {
  const listing = {...valid, active: true};
  assert.doesNotThrow(() => canReserve(listing, 2, now));
  for (const quantity of [0, -1, 1.5, 3, NaN, 101]) assert.throws(() => canReserve(listing, quantity, now));
  assert.throws(() => canReserve({...listing, active: false}, 1, now));
  assert.throws(() => canReserve({...listing, pickupEnd: now}, 1, now));
});
