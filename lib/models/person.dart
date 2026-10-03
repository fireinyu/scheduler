/// Represents a member of the team.
/// Conforms to common.schema.json#/$defs/person.
class Person {
  final int personId;
  String name;

  Person({
    required this.personId,
    required this.name,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      personId: json['personId'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'personId': personId,
      'name': name,
    };
  }

  Person copyWith({
    int? personId,
    String? name,
  }) {
    return Person(
      personId: personId ?? this.personId,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          personId == other.personId;

  @override
  int get hashCode => personId.hashCode;

  @override
  String toString() => 'Person(personId: $personId, name: $name)';
}
