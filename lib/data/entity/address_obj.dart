class AddressObj {
  final String street1;
  final String? street2;
  final String city;
  final String? state;
  final String country;
  final String postalcode;

  AddressObj({
    required this.street1,
    this.street2,
    required this.city,
    this.state,
    required this.country,
    required this.postalcode,
  });

  factory AddressObj.fromJson(Map<String, dynamic> json) {
    return AddressObj(
      street1: json['street1'],
      street2: json['street2'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      postalcode: json['postalcode'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'street1': street1,
      'street2': street2,
      'city': city,
      'state': state,
      'country': country,
      'postalcode': postalcode,
    };
  }
}
