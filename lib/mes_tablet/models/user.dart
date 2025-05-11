class User {
  final String id;
  final String name;
  final String role;
  final String? email;
  final String? photoUrl;

  User({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.photoUrl,
  });

  // Create a copy with updated fields
  User copyWith({
    String? name,
    String? role,
    String? email,
    String? photoUrl,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

// Mock user data
final List<User> demoUsers = [
  User(
    id: '1',
    name: 'John Smith',
    photoUrl: 'assets/images/user1.jpg',
    role: 'Operator',
  ),
  User(
    id: '2',
    name: 'Jane Doe',
    photoUrl: 'assets/images/user2.jpg',
    role: 'Operator',
  ),
  User(
    id: '3',
    name: 'Mike Johnson',
    photoUrl: 'assets/images/user3.jpg',
    role: 'Supervisor',
  ),
];
