/// Mirrors `TripStateMachine::allStates()`
/// (backend/app/Services/Trips/TripStateMachine.php) exactly — every
/// status a trip can ever be in, used to render both `AdminTripsScreen`'s
/// filter chips and each trip card's status chip. Kept separate from
/// `AdminVehicle`/`AdminDriver`'s status-label maps since trips have their
/// own, much longer lifecycle (a linear chain rather than a flat enum).
const Map<String, String> tripStatusLabels = {
  'draft': 'مسودة',
  'assigned': 'مُسندة',
  'accepted': 'مقبولة',
  'loading': 'جاري التحميل',
  'loaded': 'تم التحميل',
  'started': 'بدأت',
  'in_transit': 'في الطريق',
  'arrived': 'وصلت',
  'delivered': 'تم التسليم',
  'completed': 'مكتملة',
  'cancelled': 'ملغاة',
  'failed': 'فشلت',
};
