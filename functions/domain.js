'use strict';
class InputError extends Error {}
function text(value, name, max = 200) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
    throw new InputError(`${name} is required (maximum ${max} characters).`);
  }
  return value.trim();
}
function identifier(value, name) {
  const id = text(value, name, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(id)) throw new InputError(`Invalid ${name}.`);
  return id;
}
function integer(value, name, min = 1, max = 1000000) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new InputError(`${name} must be a whole number from ${min} to ${max}.`);
  }
  return value;
}
function listingInput(data, now = Date.now()) {
  const title = text(data.title, 'Food name', 100);
  const description = text(data.description, 'Description', 1000);
  const address = text(data.address, 'Pickup address', 300);
  const dietary = text(data.dietary, 'Dietary/allergen information', 500);
  const category = text(data.category, 'Category', 30);
  if (!['Bakery', 'Meals', 'Pastries', 'Other'].includes(category)) throw new InputError('Invalid category.');
  const priceCents = integer(data.priceCents, 'Price', 1);
  const originalPriceCents = integer(data.originalPriceCents, 'Original price', priceCents);
  const stock = integer(data.stock, 'Stock', 1, 10000);
  const start = data.pickupStart;
  const end = data.pickupEnd;
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start <= now ||
      end <= start || end - now > 30 * 86400000) {
    throw new InputError('Choose a future pickup window within the next 30 days.');
  }
  return {title, description, address, dietary, category, priceCents, originalPriceCents, stock,
    pickupStart: start, pickupEnd: end};
}
function canReserve(listing, quantity, now = Date.now()) {
  integer(quantity, 'Quantity', 1, 100);
  if (!listing.active || listing.pickupEnd <= now) throw new InputError('This listing is no longer available.');
  if (listing.stock < quantity) throw new InputError('Not enough stock remains.');
}
module.exports = {InputError, text, identifier, integer, listingInput, canReserve};
