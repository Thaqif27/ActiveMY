import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import 'admin_layout.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _updating = false;

  Future<void> _changeUserRole(UserModel user) async {
    String selectedRole = user.role;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Role for ${user.displayName.isNotEmpty ? user.displayName : user.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select role privilege level:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User (Athlete)')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedRole = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      if (selectedRole == user.role) return; // No change

      setState(() => _updating = true);
      try {
        final firestore = context.read<FirestoreService>();
        await firestore.updateUserRole(uid: user.uid, role: selectedRole);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully updated role to $selectedRole.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update user role: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _updating = false);
        }
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
            'Are you sure you want to permanently delete the account for ${user.email}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _updating = true);
      try {
        final firestore = context.read<FirestoreService>();
        await firestore.deleteUser(user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _updating = false);
        }
      }
    }
  }

  Future<void> _viewUserDetails(UserModel user) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          decoration: AppDecorations.glassCard.copyWith(
            borderRadius: BorderRadius.circular(28),
            color: AppColors.darkSurface.withValues(alpha: 0.95),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName.isNotEmpty ? user.displayName : 'ActiveUser',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              Text(
                user.email,
                style: const TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 32),
              
              // Details
              _buildModernDetailRow(Icons.phone, 'Phone', user.phoneNumber.isEmpty ? '-' : user.phoneNumber),
              _buildModernDetailRow(Icons.info_outline, 'Bio', user.bio.isEmpty ? '-' : user.bio),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('EMERGENCY CONTACT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              _buildModernDetailRow(Icons.person_outline, 'Name', user.emergencyContactName.isEmpty ? '-' : user.emergencyContactName),
              _buildModernDetailRow(Icons.phone_in_talk, 'Phone', user.emergencyContactPhone.isEmpty ? '-' : user.emergencyContactPhone),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('PREFERENCES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              _buildModernDetailRow(Icons.category, 'Categories', user.preferredCategories.isEmpty ? 'None' : user.preferredCategories.join(', ')),
              _buildModernDetailRow(Icons.map, 'Radius', user.preferredRadiusKm.isFinite ? '${user.preferredRadiusKm.toInt()} km' : '∞ km'),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Close Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 14)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        hoverColor: color.withValues(alpha: 0.2),
        splashRadius: 20,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return _buildAccessDenied(context);
    }

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(currentUser.uid),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting && !authSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final userProfile = authSnapshot.data;
        if (userProfile == null || !userProfile.isAdmin) {
          return _buildAccessDenied(context);
        }

        return StreamBuilder<List<UserModel>>(
          stream: firestore.streamAllUsers(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting && !usersSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: AppColors.darkBg,
                body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }

            final users = usersSnapshot.data ?? [];

            return AdminLayout(
              activeRoute: RoutePaths.adminUsers,
              title: 'User Account Roles',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_updating)
                    const LinearProgressIndicator(color: AppColors.primary, backgroundColor: Colors.transparent),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Text(
                      'System Users',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                    ),
                  ),

                  // Users Table
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24.0),
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isUserAdmin = user.role == 'admin';
                        
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppAdminColors.cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppAdminColors.border),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isUserAdmin ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                                child: Text(
                                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold, 
                                    color: isUserAdmin ? Colors.purpleAccent : Colors.blueAccent
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              
                              // User Info
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName.isNotEmpty ? user.displayName : 'ActiveUser',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Role Badge
                              Expanded(
                                flex: 1,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isUserAdmin ? Colors.purpleAccent.withValues(alpha: 0.15) : Colors.blueAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(color: isUserAdmin ? Colors.purpleAccent.withValues(alpha: 0.3) : Colors.blueAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      user.role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isUserAdmin ? Colors.purpleAccent : Colors.blueAccent,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildActionBtn(
                                    icon: Icons.visibility_outlined,
                                    color: Colors.greenAccent,
                                    tooltip: 'View Details',
                                    onPressed: () => _viewUserDetails(user),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionBtn(
                                    icon: Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                    tooltip: 'Edit Role',
                                    onPressed: () => _changeUserRole(user),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionBtn(
                                    icon: Icons.delete_outline,
                                    color: Colors.redAccent,
                                    tooltip: 'Delete User',
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: AppDecorations.glassCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: Colors.redAccent, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'You do not have administrative privileges to access this panel. Only admin roles are allowed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(RoutePaths.login),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
