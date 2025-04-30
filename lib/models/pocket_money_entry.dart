class PocketMoneyEntry {
  int amount;
  DateTime date;
  bool confirmed;
  int userId;
  int? id;

  PocketMoneyEntry({
    required this.amount,
    required this.date,
    this.confirmed = false,
    required this.userId,
    this.id,
  });

  factory PocketMoneyEntry.fromJson(Map<String, dynamic> json) {
    return PocketMoneyEntry(
      id: json['id'] as int,
      date: DateTime.parse(json['date']),
      confirmed: json['confirmed'] as bool,
      amount: (json['amount'] as num).toInt(),
      userId: json['user_id'] as int,
    );
  }
}

class CreatePocketMoneyEntry {
  double amount;
  DateTime date;
  int userId;

  CreatePocketMoneyEntry({
    required this.amount,
    required this.date,
    required this.userId,
  });

}