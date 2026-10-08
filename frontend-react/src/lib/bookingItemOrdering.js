export function orderedTransportBookingItems(items) {
  return (Array.isArray(items) ? items : [])
    .filter((item) => item.itemType === 2 || item.itemType === 'Transport' || item.transportType || item.transportOptionId)
    .slice()
    .sort((left, right) => {
      const leftIndex = left.transportLegIndex != null && left.transportLegIndex !== '' && Number.isInteger(Number(left.transportLegIndex)) && Number(left.transportLegIndex) >= 0
        ? Number(left.transportLegIndex)
        : null
      const rightIndex = right.transportLegIndex != null && right.transportLegIndex !== '' && Number.isInteger(Number(right.transportLegIndex)) && Number(right.transportLegIndex) >= 0
        ? Number(right.transportLegIndex)
        : null
      if (leftIndex == null && rightIndex != null) return 1
      if (leftIndex != null && rightIndex == null) return -1
      if (leftIndex != null && rightIndex != null && leftIndex !== rightIndex) return leftIndex - rightIndex
      return Number(left.id || 0) - Number(right.id || 0)
    })
}
