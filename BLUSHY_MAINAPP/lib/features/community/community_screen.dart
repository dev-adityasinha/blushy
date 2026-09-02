import 'dart:async';
import '../../shared/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../models/community_models.dart';
import '../../services/reddit_community_service.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_sheet.dart';
import '../../services/html_audio_helper.dart';
import '../../services/api_sia_service.dart';
import 'moderation_widgets.dart';
import '../../l10n/app_localizations.dart';

/// Whether a post matches what was typed in the search box.
///
/// The box says "title, text, tags, or username", but the author was never
/// checked -- so searching someone's name found them under People and none of
/// their posts, which read as only people being searched.
///
/// This looks at the posts already loaded for the current feed. There is no
/// server-side post search to call: `/posts/feed` takes a feed type and
/// nothing else.
bool communityPostMatches(CommunityPost post, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;

  return post.title.toLowerCase().contains(needle) ||
      post.text.toLowerCase().contains(needle) ||
      post.authorName.toLowerCase().contains(needle) ||
      post.tags.any((tag) => tag.toLowerCase().contains(needle));
}

class BlushyCommunityScreen extends StatefulWidget {
  const BlushyCommunityScreen({super.key});

  @override
  State<BlushyCommunityScreen> createState() => _BlushyCommunityScreenState();
}

class _BlushyCommunityScreenState extends State<BlushyCommunityScreen> with TickerProviderStateMixin {
  final _redditService = RedditCommunityService();
  final ApiSiaService _siaService = ApiSiaService();
  final TextEditingController _searchController = TextEditingController();

  HtmlAudioRecorder? _searchAudioRecorder;
  bool _isListeningSearchVoice = false;
  bool _isTranscribingSearchVoice = false;

  String _activeTab = 'Home'; // Home, Trending, Latest, Following

  /// Whether the create-post button is showing its label.
  ///
  /// It sits collapsed as a plain `+`, and expands for [_labelFlash] whenever
  /// the feed filter changes -- long enough to say what the button does,
  /// brief enough that it is not permanently covering the feed.
  bool _isCreateLabelShowing = false;
  Timer? _createLabelTimer;
  static const Duration _labelFlash = Duration(seconds: 2);

  /// The feed filters, in order, each with the icon that sits before its name.
  /// Kept as one list so the row and the chips cannot fall out of step.
  static const Map<String, IconData> _feedTabs = <String, IconData>{
    'Home': Icons.home_rounded,
    'Trending': Icons.trending_up_rounded,
    'Latest': Icons.schedule_rounded,
    'Following': Icons.people_rounded,
  };
  String _searchQuery = '';
  List<CommunityPost> _allPosts = [];
  List<CommunityPost> _feedPosts = [];
  bool _isLoadingFeed = true;

  List<UserProfileData> _matchedUsers = [];
  bool _isLoadingUsers = false;
  Timer? _searchDebounce;

  Future<void> _toggleSearchVoiceSTT() async {
    if (_isListeningSearchVoice && _searchAudioRecorder != null) {
      setState(() {
        _isListeningSearchVoice = false;
        _isTranscribingSearchVoice = true;
      });

      try {
        final recordResult = await _searchAudioRecorder!.stop();
        final audioBytes = recordResult?.bytes ?? [];
        if (audioBytes.isNotEmpty) {
          final transcribedText = await _siaService.transcribeAudioBytes(
            audioBytes,
            'community_search_${DateTime.now().millisecondsSinceEpoch}.webm',
          );

          if (mounted) {
            setState(() {
              _isTranscribingSearchVoice = false;
            });
            if (transcribedText.trim().isNotEmpty) {
              _searchController.text = transcribedText.trim();
              setState(() {
                _searchQuery = transcribedText.trim();
                _filterPosts();
              });
              _performUserSearch(_searchQuery);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Voice transcribed into search bar!")),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isTranscribingSearchVoice = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isTranscribingSearchVoice = false;
          });
        }
      }
    } else {
      try {
        _searchAudioRecorder = HtmlAudioRecorder();
        await _searchAudioRecorder!.start();
        if (mounted) {
          setState(() {
            _isListeningSearchVoice = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListeningSearchVoice = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _createLabelTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Expands the create-post button briefly, then lets it collapse again.
  void _flashCreateLabel() {
    // Held so it can be cancelled: changing filter twice inside the window
    // should restart it, not leave the first timer to collapse the button
    // early. An uncancelled timer also fires after dispose.
    _createLabelTimer?.cancel();
    setState(() => _isCreateLabelShowing = true);
    _createLabelTimer = Timer(_labelFlash, () {
      if (mounted) setState(() => _isCreateLabelShowing = false);
    });
  }

  Future<void> _performUserSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _matchedUsers = [];
        _isLoadingUsers = false;
      });
      return;
    }

    setState(() {
      _isLoadingUsers = true;
    });

    final results = await _redditService.searchUsers(cleanQuery);

    if (mounted && _searchQuery.trim() == cleanQuery) {
      setState(() {
        _matchedUsers = results;
        _isLoadingUsers = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCommunityFeed();
  }

  Future<void> _fetchCommunityFeed() async {
    setState(() {
      _isLoadingFeed = true;
    });
    final type = _activeTab.toLowerCase();
    // The term goes to the server so the whole feed is searched, not just the
    // page already loaded. The local filter below still runs, which keeps
    // typing responsive between round trips.
    final query = _searchQuery.trim();
    final posts = await _redditService.getFeed(type, search: query);
    if (!mounted) return;
    // A slower earlier request must not overwrite a newer search.
    if (_searchQuery.trim() != query) return;
    setState(() {
      _allPosts = posts;
      _filterPosts();
      _isLoadingFeed = false;
    });
  }

  void _filterPosts() {
    final query = _searchQuery.trim();
    _feedPosts = query.isEmpty
        ? List.from(_allPosts)
        : _allPosts.where((post) => communityPostMatches(post, query)).toList();
  }

  /// Applies a vote to the feed straight away, then reconciles with the server.
  ///
  /// The count used to move only after the feed was reloaded. The request
  /// itself was fine -- the server records the vote and returns the new score
  /// -- but `votePost` turns any failure, a timeout included, into `null`, and
  /// `null` left the UI untouched. So a slow request (the API sleeps when idle,
  /// and the first call after that can take a minute) counted the vote and
  /// showed nothing for it, which reads as the tap not having worked.
  ///
  /// Showing it immediately is also just correct: this is her own tap, and she
  /// should not wait on a round trip to see it.
  Future<void> _votePost(CommunityPost post, int voteVal) async {
    final targetVote = post.userVote == voteVal ? 0 : voteVal;

    final idx = _allPosts.indexWhere((p) => p.postId == post.postId);
    if (idx == -1) return;

    final before = _allPosts[idx];
    // The score is a net total, so switching a downvote to an upvote moves it
    // by two, not one.
    final predicted = before.withVote(
      userVote: targetVote,
      score: before.score - before.userVote + targetVote,
    );

    setState(() {
      _allPosts[idx] = predicted;
      _filterPosts();
    });

    final updated = await _redditService.votePost(post.postId, targetVote);
    if (!mounted) return;

    setState(() {
      final at = _allPosts.indexWhere((p) => p.postId == post.postId);
      if (at == -1) return;
      // The server's number wins when it answers. When it does not, the
      // prediction stands: the vote was almost certainly recorded, and
      // reverting a tap she just made would be the more confusing of the two.
      if (updated != null) _allPosts[at] = updated;
      _filterPosts();
    });
  }

  void _showProfile(String authorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileSheet(userId: authorId),
    );
  }

  Future<void> _navigateToCreatePost() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
    if (created == true) {
      _fetchCommunityFeed();
    }
  }

  Future<void> _navigateToPostDetail(CommunityPost post) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
    if (updated == true) {
      _fetchCommunityFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      floatingActionButton: FloatingActionButton.extended(
        // Collapsed to a `+` unless the label is flashing, so it does not sit
        // over the feed saying the same thing all session.
        isExtended: _isCreateLabelShowing,
        onPressed: _navigateToCreatePost,
        backgroundColor: BlushyColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Create Post',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCommunityFeed,
          color: BlushyColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 1. Search Bar
                _buildSearchBar(),

                // 2. Feed Navigation Tabs (Home, Trending, Latest, Following)
                _buildNavigationTabs(),

                const SizedBox(height: 16),

                // People Section
                _buildMatchedUsersSection(),

                // 3. Feed Items
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context)),
                  child: _buildCommunityFeed(),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: BlushyColors.secondaryText, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _filterPosts();
                  });
                  if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    _performUserSearch(val);
                    _fetchCommunityFeed();
                  });
                },
                style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).cSearchTitleTextTags,
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _filterPosts();
                    _matchedUsers = [];
                  });
                },
                child: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText, size: 18),
              ),
            const SizedBox(width: 8),
            if (_isTranscribingSearchVoice)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BlushyColors.primary,
                ),
              )
            else
              GestureDetector(
                onTap: _toggleSearchVoiceSTT,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isListeningSearchVoice ? BlushyColors.primary : const Color(0xFFF5EFE6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListeningSearchVoice ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isListeningSearchVoice ? Colors.white : BlushyColors.secondaryText,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTabs() {
    // All four share the width instead of running off the edge. Scrolling put
    // the last filter behind a gesture nobody had a reason to try.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: BlushyTheme.getPagePadding(context),
      ),
      child: Row(
        children: [
          for (final label in _feedTabs.keys)
            Expanded(child: _buildTabItem(label)),
        ],
      ),
    );
  }

  /// One feed filter, as a chip that fills with red when it is the one in use.
  ///
  /// This was a text label with a two-pixel rule under it, which is a small
  /// target and a quiet signal for the control that decides what the whole
  /// feed shows.
  Widget _buildTabItem(String label) {
    final active = _activeTab == label;
    final foreground = active ? Colors.white : BlushyColors.secondaryText;

    return Padding(
      // Even gaps, so the row reads as four equal filters.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () {
            if (_activeTab != label) {
              setState(() {
                _activeTab = label;
              });
              _flashCreateLabel();
              _fetchCommunityFeed();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
            decoration: BoxDecoration(
              color: active ? BlushyColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? BlushyColors.primary : BlushyColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_feedTabs[label], size: 12, color: foreground),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchedUsersSection() {
    if (_searchQuery.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).cPeople,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                ),
              ),
              if (_isLoadingUsers) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: BlushyColors.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (!_isLoadingUsers && _matchedUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'No matching people found.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: BlushyColors.secondaryText.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _matchedUsers.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final user = _matchedUsers[index];
                  return GestureDetector(
                    onTap: () => _showProfile(user.userId),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: BlushyColors.border.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5EFE6),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: BlushyColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user.displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: BlushyColors.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (user.email.isNotEmpty)
                                  Text(
                                    user.email,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      color: BlushyColors.secondaryText.withValues(alpha: 0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          const Divider(color: BlushyColors.border, height: 1),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCommunityFeed() {
    if (_isLoadingFeed) {
      // Post-shaped, so the feed does not jump when the real posts arrive and
      // a slow load looks like a feed filling in rather than a stalled screen.
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            SkeletonPostCard(),
            SkeletonPostCard(),
            SkeletonPostCard(),
          ],
        ),
      );
    }

    if (_feedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60.0),
          child: Column(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: BlushyColors.secondaryText),
              const SizedBox(height: 12),
              Text(
                'No posts found in this feed.',
                style: GoogleFonts.poppins(color: BlushyColors.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _feedPosts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final post = _feedPosts[index];
        return _buildRedditPostCard(post);
      },
    );
  }

  Widget _buildRedditPostCard(CommunityPost post) {
    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border.withValues(alpha: 0.6), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x042E2623),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (Author, Timestamp)
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showProfile(post.authorId),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5EFE6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showProfile(post.authorId),
                        child: Text(
                          post.authorName,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•  ${_timeAgo(post.createdAt)}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: BlushyColors.secondaryText.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Report and block. Visibility itself is enforced server side;
                // these are the actions available to the reader.
                PostModerationMenu(
                  postId: post.postId,
                  authorId: post.authorId,
                  onBlocked: () {
                    setState(() {
                      _allPosts.removeWhere((p) => p.authorId == post.authorId);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Post Title & Body snippet
            Text(
              post.title,
              style: GoogleFonts.poppins(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
                height: 1.3,
              ),
            ),
            if (post.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: BlushyColors.text.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ],
            ModerationNotice(notice: post.moderationNotice),
            const SizedBox(height: 14),

            // Tags
            if (post.tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EFE6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Score and actions footer (Heart Like, Dislike, and Comment)
            Row(
              children: [
                // LIKE BUTTON
                InkWell(
                  onTap: () {
                    final targetVote = post.userVote == 1 ? 0 : 1;
                    _votePost(post, targetVote);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.userVote == 1 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 22,
                          color: const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          // The server's score is the count. Clamped only so a
                          // net-negative post does not show a negative number
                          // beside a heart.
                          '${post.score < 0 ? 0 : post.score}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // DISLIKE BUTTON
                InkWell(
                  onTap: () {
                    final targetVote = post.userVote == -1 ? 0 : -1;
                    _votePost(post, targetVote);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.userVote == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                          size: 20,
                          color: post.userVote == -1 ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // COMMENT BUTTON
                InkWell(
                  onTap: () => _navigateToPostDetail(post),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                          color: Color(0xFF4A4A4A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentCount}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}

