class Customer {
  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.notes,
  });

  final int? id;
  final String name;
  final String? phone;
  final String? notes;

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    bool clearPhone = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: clearPhone ? null : phone ?? this.phone,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
      };

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
