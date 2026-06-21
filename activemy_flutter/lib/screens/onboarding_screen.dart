import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Set<String> _selectedCategories = {};
  bool _saving = false;

  Future<void> _savePreferences() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category to continue.')),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user = auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session expired. Please log in again.')),
      );
      return;
    }

    setState(() => _saving = true);

    final profile = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      role: 'user',
      preferredCategories: _selectedCategories.toList(),
      preferredRadiusKm: AppConstants.defaultRadiusKm,
      fcmToken: '',
      createdAt: DateTime.now(),
    );

    try {
      await firestore.createUserIfMissing(profile);
      await firestore.updateUserPreferences(
        uid: user.uid,
        categories: _selectedCategories.toList(),
        radiusKm: AppConstants.defaultRadiusKm,
      );

      if (mounted) {
        context.go(RoutePaths.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Personalize Your Experience',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick your favorite outdoor sports categories. We will customize your dashboard and suggestions accordingly.',
                style: TextStyle(color: AppColors.textLight, height: 1.5),
              ),
              const SizedBox(height: 48),
              
              // Category Selection Wrap
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppConstants.categories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return FilterChip(
                    avatar: _getCategoryIcon(category, isSelected),
                    label: Text(category.toUpperCase()),
                    selected: isSelected,
                    selectedColor: _getCategoryColor(category).withValues(alpha: 0.15),
                    checkmarkColor: _getCategoryColor(category),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _getCategoryColor(category) : AppColors.textDark,
                    ),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: _saving ? null : _savePreferences,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _getCategoryIcon(String category, bool isSelected) {
    IconData icon;
    switch (category.toLowerCase()) {
      case 'running':
        icon = Icons.directions_run;
        break;
      case 'cycling':
        icon = Icons.directions_bike;
        break;
      case 'hiking':
        icon = Icons.terrain;
        break;
      default:
        return null;
    }
    return Icon(
      icon,
      size: 18,
      color: isSelected ? _getCategoryColor(category) : AppColors.textLight,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'running':
        return AppColors.running;
      case 'cycling':
        return AppColors.cycling;
      case 'hiking':
        return AppColors.hiking;
      default:
        return Colors.grey;
    }
  }
}
