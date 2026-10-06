export function formatPrice(amount, currency = 'LKR') {
  return `${currency} ${Number(amount ?? 0).toLocaleString('en-US', { maximumFractionDigits: 2 })}`
}
