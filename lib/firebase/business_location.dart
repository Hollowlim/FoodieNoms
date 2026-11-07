/// The approximate Subang Jaya pilot map area used by the business editor.
const pilotSouth = 2.98;
const pilotNorth = 3.12;
const pilotWest = 101.54;
const pilotEast = 101.64;

bool isPilotShopLocation(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= pilotSouth &&
    latitude <= pilotNorth &&
    longitude >= pilotWest &&
    longitude <= pilotEast;

class ShopMapPin {
  const ShopMapPin(
      {required this.id,
      required this.name,
      required this.address,
      required this.latitude,
      required this.longitude});
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  /// Unconfigured businesses never acquire a made-up map position.
  static ShopMapPin? fromData(String id, Map<String, dynamic> data) {
    final latitude =
        data['latitude'] is num ? (data['latitude'] as num).toDouble() : null;
    final longitude =
        data['longitude'] is num ? (data['longitude'] as num).toDouble() : null;
    final name =
        data['businessName'] is String ? data['businessName'] as String : '';
    final address = data['address'] is String ? data['address'] as String : '';
    if (data['configured'] != true ||
        !isPilotShopLocation(latitude, longitude) ||
        name.trim().isEmpty ||
        address.trim().isEmpty) {
      return null;
    }
    return ShopMapPin(
        id: id,
        name: name,
        address: address,
        latitude: latitude!,
        longitude: longitude!);
  }
}
