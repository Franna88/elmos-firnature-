import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/sop_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final sopService = Provider.of<SOPService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              "elmo's",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "F U R N I T U R E",
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xffB21E1E),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Text(
                  'User Name',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    color: Color(0xffB21E1E),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.notifications_outlined),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              color: const Color(0xffB21E1E),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "elmo's",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "F U R N I T U R E",
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home, color: Color(0xffB21E1E)),
                    title: const Text('Home'),
                    selected: true,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.apps, color: Color(0xffB21E1E)),
                    title: const Text('My SOPs'),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to SOPs list
                      context.go('/sops');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description, color: Color(0xffB21E1E)),
                    title: const Text('Templates'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/templates');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.stacked_bar_chart, color: Color(0xffB21E1E)),
                    title: const Text('Analytics'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/analytics');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Color(0xffB21E1E)),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/settings');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${authService.userName ?? 'User'}!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage your Standard Operating Procedures efficiently with our platform.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to create new SOP
                              context.go('/editor/new');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New SOP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffB21E1E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.go('/analytics');
                            },
                            icon: const Icon(Icons.analytics),
                            label: const Text('View Analytics'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff17A2B8),
                              side: const BorderSide(color: Color(0xff17A2B8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Recent SOPs section
            Text(
              'Recent SOPs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            sopService.sops.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No SOPs created yet. Create your first SOP to get started!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sopService.sops.length > 3
                        ? 3
                        : sopService.sops.length,
                    itemBuilder: (context, index) {
                      final sop = sopService.sops[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(sop.title),
                          subtitle: Text(
                            'Department: ${sop.department} • Rev: ${sop.revisionNumber}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            context.go('/editor/${sop.id}');
                          },
                        ),
                      );
                    },
                  ),
            if (sopService.sops.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to all SOPs
                    context.go('/sops');
                  },
                  child: const Text('View All SOPs'),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Templates section
            Text(
              'Templates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: sopService.templates.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No templates available.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sopService.templates.length,
                      itemBuilder: (context, index) {
                        final template = sopService.templates[index];
                        return Card(
                          margin: const EdgeInsets.only(right: 16),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  template.description,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () {
                                        // View template
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xff17A2B8),
                                        side: const BorderSide(color: Color(0xff17A2B8)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        minimumSize: const Size(60, 30),
                                      ),
                                      child: const Text('View'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        // Edit template
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xff6F42C1),
                                        side: const BorderSide(color: Color(0xff6F42C1)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        minimumSize: const Size(60, 30),
                                      ),
                                      child: const Text('Edit'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  context.go('/templates');
                },
                child: const Text('View All Templates'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/editor/new');
        },
        backgroundColor: const Color(0xffB21E1E),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
} 