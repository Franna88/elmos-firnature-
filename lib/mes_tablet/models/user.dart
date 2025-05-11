class User {
  final String id;
  final String name;
  final String? photoUrl;
  final String role;

  User({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.role,
  });
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