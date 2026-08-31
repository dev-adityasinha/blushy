import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../models/community_models.dart';
import '../../services/reddit_community_service.dart';
import '../../services/auth_storage.dart';
import '../../l10n/app_localizations.dart';

class UserProfileSheet extends StatefulWidget {
  final String userId;

  const UserProfileSheet({super.key, required this.userId});

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  final _redditService = RedditCommunityService();
  UserProfileData? _profile;
  bool _isLoading = true;
  bool _isFollowingAction = false;
  late String _currentUserId;
  bool _isEditingBio = false;
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserId = AuthStorage.getUserId() ?? '';
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final data = await _redditService.getUserProfile(widget.userId);
    if (data != null) {
      setState(() {
        _profile = data;
        _bioController.text = data.bio;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;

    setState(() {
      _isFollowingAction = true;
    });

    try {
      bool success;
      if (_profile!.isFollowing) {
        success = await _redditService.unfollowUser(_profile!.userId);
      } else {
        success = await _redditService.followUser(_profile!.userId);
      }

      if (success) {
        // Reload profile data to get updated followersCount and follow state
        await _loadProfile();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update follow status')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating follow status: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowingAction = false;
        });
      }
    }
  }

  Future<void> _saveBio() async {
    final bio = _bioController.text.trim();
    setState(() {
      _isLoading = true;
    });

    try {
      final updated = await _redditService.updateUserProfile(bio);
      if (updated != null) {
        if (mounted) {
          setState(() {
            _profile = updated;
            _isEditingBio = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save bio')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bio: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == _currentUserId;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _isLoading && _profile == null
          ? const SizedBox(
              height: 250,
              child: Center(
                child: CircularProgressIndicator(color: BlushyColors.primary),
              ),
            )
          : _profile == null
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).upFailedToLoadProfile,
                      style: GoogleFonts.poppins(color: BlushyColors.secondaryText),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle line drag indicator
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: BlushyColors.border.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // User Header
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5EFE6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _profile!.displayName.isNotEmpty
                                ? _profile!.displayName[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: BlushyColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile!.displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: BlushyColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_profile!.karma} Karma',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: BlushyColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isOwnProfile)
                          ElevatedButton(
                            onPressed: _isFollowingAction ? null : _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _profile!.isFollowing ? const Color(0xFFF5EFE6) : BlushyColors.primary,
                              foregroundColor: _profile!.isFollowing ? BlushyColors.text : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: _isFollowingAction
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _profile!.isFollowing ? 'Following' : 'Follow',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                          )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats row
                    Row(
                      children: [
                        _buildStatColumn('Followers', _profile!.followersCount),
                        const SizedBox(width: 24),
                        _buildStatColumn('Following', _profile!.followingCount),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bio section
                    Text(
                      'Biography',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_isEditingBio) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EFE6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _bioController,
                          maxLines: 3,
                          style: GoogleFonts.poppins(fontSize: 13.5, color: BlushyColors.text),
                          decoration: const InputDecoration(
                            hintText: 'Tell the community about yourself...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isEditingBio = false),
                            child: Text(
                              AppLocalizations.of(context).upCancel,
                              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveBio,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BlushyColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              AppLocalizations.of(context).upSave,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    ] else ...[
                      Text(
                        _profile!.bio.isNotEmpty ? _profile!.bio : 'No biography added yet.',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: BlushyColors.text.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                      if (isOwnProfile) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _isEditingBio = true),
                          icon: const Icon(Icons.edit_rounded, size: 14, color: BlushyColors.primary),
                          label: Text(
                            'Edit Biography',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: BlushyColors.primary, width: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: BlushyColors.secondaryText.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
