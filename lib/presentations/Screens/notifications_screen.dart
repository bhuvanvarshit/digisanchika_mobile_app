// lib/presentations/Screens/notifications_screen.dart
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sample data for notifications
  final List<Map<String, dynamic>> _publicNotifications = [
    {
      'id': '1',
      'title': 'System Maintenance',
      'message': 'System will be down for maintenance from 2 AM to 4 AM',
      'time': '2 hours ago',
      'read': false,
      'icon': Icons.system_update,
      'color': Colors.blue,
    },
    {
      'id': '2',
      'title': 'New Feature Released',
      'message': 'Check out the new reporting dashboard feature',
      'time': '1 day ago',
      'read': true,
      'icon': Icons.new_releases,
      'color': Colors.green,
    },
    {
      'id': '3',
      'title': 'Holiday Announcement',
      'message': 'Office will remain closed on Monday for public holiday',
      'time': '3 days ago',
      'read': true,
      'icon': Icons.celebration,
      'color': Colors.orange,
    },
  ];

  final List<Map<String, dynamic>> _sharedNotifications = [
    {
      'id': '4',
      'title': 'Document Shared',
      'message': 'John shared "Q3 Report" with you',
      'time': '30 minutes ago',
      'read': false,
      'icon': Icons.share,
      'color': Colors.purple,
    },
    {
      'id': '5',
      'title': 'File Comment',
      'message': 'Sarah commented on your "Budget Proposal" file',
      'time': '2 hours ago',
      'read': false,
      'icon': Icons.comment,
      'color': Colors.teal,
    },
    {
      'id': '6',
      'title': 'Collaboration Request',
      'message': 'Mike requested to collaborate on "Project Plan"',
      'time': '1 day ago',
      'read': true,
      'icon': Icons.group_add,
      'color': Colors.indigo,
    },
    {
      'id': '7',
      'title': 'Folder Access',
      'message': 'You now have access to "Client Documents" folder',
      'time': '2 days ago',
      'read': true,
      'icon': Icons.folder_open,
      'color': Colors.brown,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Build notification item
  Widget _buildNotificationItem(
    Map<String, dynamic> notification,
    bool isPublic,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification['read'] ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification['read']
              ? Colors.grey.shade200
              : Colors.blue.shade100,
          width: 1,
        ),
        boxShadow: notification['read']
            ? []
            : [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: notification['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            notification['icon'],
            color: notification['color'],
            size: 24,
          ),
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: notification['read']
                ? FontWeight.w500
                : FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'],
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPublic ? Icons.public : Icons.people,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  isPublic ? 'Public' : 'Shared',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Text(
                  notification['time'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        trailing: notification['read']
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          // Mark as read on tap
          setState(() {
            notification['read'] = true;
          });
        },
      ),
    );
  }

  // Mark all as read
  void _markAllAsRead(bool isPublic) {
    setState(() {
      if (isPublic) {
        for (var notification in _publicNotifications) {
          notification['read'] = true;
        }
      } else {
        for (var notification in _sharedNotifications) {
          notification['read'] = true;
        }
      }
    });
  }

  // Clear all notifications
  void _clearAllNotifications(bool isPublic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Notifications'),
        content: Text(
          'Are you sure you want to clear all ${isPublic ? 'public' : 'shared'} notifications?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (isPublic) {
                  _publicNotifications.clear();
                } else {
                  _sharedNotifications.clear();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadPublicCount = _publicNotifications
        .where((n) => !n['read'])
        .length;
    final unreadSharedCount = _sharedNotifications
        .where((n) => !n['read'])
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 43, 65, 189),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white, // Add this
          unselectedLabelColor: Colors.white.withOpacity(0.7), // Add this
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.public, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Public', style: TextStyle(color: Colors.white)),
                  if (unreadPublicCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadPublicCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Shared', style: TextStyle(color: Colors.white)),
                  if (unreadSharedCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadSharedCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Public Notifications Tab
          _buildNotificationsList(true),
          // Shared Notifications Tab
          _buildNotificationsList(false),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isPublic) {
    final notifications = isPublic
        ? _publicNotifications
        : _sharedNotifications;

    return notifications.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPublic ? Icons.public : Icons.share,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  isPublic
                      ? 'No Public Notifications'
                      : 'No Shared Notifications',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  isPublic
                      ? 'Public announcements will appear here'
                      : 'Shared files and collaborations will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAllAsRead(isPublic),
                        icon: const Icon(Icons.mark_email_read, size: 18),
                        label: const Text('Mark All as Read'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue.shade300),
                          foregroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _clearAllNotifications(isPublic),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Clear All'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300),
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Notifications list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationItem(
                      notifications[index],
                      isPublic,
                    );
                  },
                ),
              ),
            ],
          );
  }
}
