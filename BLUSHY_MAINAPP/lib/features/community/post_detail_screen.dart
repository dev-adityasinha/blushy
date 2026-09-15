import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../models/community_models.dart';
import '../../services/reddit_community_service.dart';
import '../../services/auth_storage.dart';
import 'user_profile_sheet.dart';
import 'moderation_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/blushy_surface.dart';
import '../../theme/scale.dart';
import 'post_card_parts.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _redditService = RedditCommunityService();
  late CommunityPost _post;
  List<CommunityComment> _comments = [];
  bool _isLoadingComments = true;
  String _commentSort = 'top'; // top, new, controversial
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  CommunityComment? _replyTarget;
  bool _isSending = false;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _currentUserId = AuthStorage.getUserId() ?? '';
    _loadPostDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostDetails() async {
    setState(() {
      _isLoadingComments = true;
    });
    // Reload post metadata
    final updatedPost = await _redditService.votePost(_post.postId, _post.userVote); // no-op vote triggers update
    if (updatedPost != null) {
      _post = updatedPost;
    }

    // Load comments
    final commentsTree = await _redditService.getComments(_post.postId, _commentSort);
    setState(() {
      _comments = commentsTree;
      _isLoadingComments = false;
    });
  }

  /// Same as the feed: show the vote now, reconcile when the server answers.
  ///
  /// `votePost` returns `null` for any failure, timeouts included, and `null`
  /// left the count unchanged even though the vote had been recorded.
  Future<void> _votePost(int voteVal) async {
    final targetVote = _post.userVote == voteVal ? 0 : voteVal;
    final before = _post;

    setState(() {
      // A net score, so flipping a downvote to an upvote moves it by two.
      _post = before.withVote(
        userVote: targetVote,
        score: before.score - before.userVote + targetVote,
      );
    });

    final updated = await _redditService.votePost(before.postId, targetVote);
    if (!mounted || updated == null) return;

    setState(() {
      _post = updated;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final newComment = await _redditService.createComment(
        _post.postId,
        text,
        parentId: _replyTarget?.commentId,
      );

      if (newComment != null) {
        _commentController.clear();
        setState(() {
          _replyTarget = null;
        });
        _focusNode.unfocus();
        _loadPostDetails(); // Reload comment tree
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit comment')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting comment: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _voteComment(CommunityComment comment, int voteVal) async {
    final targetVote = comment.userVote == voteVal ? 0 : voteVal;
    final updated = await _redditService.voteComment(comment.commentId, targetVote);
    if (updated != null) {
      _loadPostDetails(); // Simple reload to refresh tree values
    }
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).pdDeleteComment, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(AppLocalizations.of(context).pdAreYouSureYou, style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).pdCancel, style: GoogleFonts.manrope(color: BlushyColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).pdDelete, style: GoogleFonts.manrope(color: BlushyColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _redditService.deleteComment(comment.commentId);
      if (success) {
        _loadPostDetails();
      }
    }
  }

  void _showProfile(String authorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileSheet(userId: authorId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: BlushyColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Discussion',
          style: GoogleFonts.manrope(height: 1.5, 
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPostDetails,
                color: BlushyColors.primary,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  children: [
                    // Post Card Detail
                    _buildPostDetailCard(),
                    const SizedBox(height: 20),

                    // Comments Header / Sort Options
                    _buildCommentsHeader(),
                    const SizedBox(height: 12),

                    // Comments List Tree
                    if (_isLoadingComments)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: CircularProgressIndicator(color: BlushyColors.primary),
                        ),
                      )
                    else if (_comments.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'No comments yet. Be the first to reply!',
                            style: GoogleFonts.manrope(height: 1.5, 
                              color: BlushyColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._buildCommentTreeWidgets(_comments, 0),
                  ],
                ),
              ),
            ),

            // Persistent Input Composer at the bottom
            _buildCommentComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostDetailCard() {
    final isOwnPost = _post.authorId == _currentUserId;

    // The same card as the feed, from the same parts. The only things that
    // differ are what this page knows and the feed does not: the live
    // comment count, and the delete control on your own post.
    return BlushySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PostAvatar(
                name: _post.authorName,
                onTap: () => _showProfile(_post.authorId),
              ),
              const SizedBox(width: BlushySpace.md),
              Expanded(
                child: PostByline(
                  name: _post.authorName,
                  timeAgo: _timeAgo(_post.createdAt),
                  onTap: () => _showProfile(_post.authorId),
                ),
              ),
              if (isOwnPost)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: BlushyColors.primary, size: 20),
                  tooltip: AppLocalizations.of(context).pdDeletePost,
                  onPressed: _confirmDelete,
                ),
            ],
          ),
          const SizedBox(height: BlushySpace.md),
          Text(_post.title, style: BlushyType.heading(weight: FontWeight.w700)),
          if (_post.text.isNotEmpty) ...[
            const SizedBox(height: BlushySpace.sm),
            Text(_post.text, style: BlushyType.body(color: BlushyColors.text)),
          ],
          ModerationNotice(notice: _post.moderationNotice),
          if (_post.tags.isNotEmpty) ...[
            const SizedBox(height: BlushySpace.lg),
            Wrap(
              spacing: BlushySpace.sm,
              runSpacing: BlushySpace.sm,
              children: [for (final tag in _post.tags) PostTagPill(tag)],
            ),
          ],
          const SizedBox(height: BlushySpace.lg),
          Row(
            children: [
              PostActionPill(
                icon: _post.userVote == 1
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                // The server's score is the count. The old fallback invented
                // a 1 whenever the viewer had voted, even at score 0.
                label: '${_post.score < 0 ? 0 : _post.score}',
                tinted: true,
                onTap: () => _votePost(_post.userVote == 1 ? 0 : 1),
              ),
              const SizedBox(width: BlushySpace.sm),
              PostActionPill(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${_comments.length}',
              ),
              const SizedBox(width: BlushySpace.sm),
              PostActionPill(
                icon: _post.userVote == -1
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
                onTap: () => _votePost(_post.userVote == -1 ? 0 : -1),
              ),
              const Spacer(),
              PostActionPill(
                icon: Icons.ios_share_rounded,
                onTap: () => Share.share(
                  _post.text.isEmpty
                      ? _post.title
                      : '${_post.title}\n\n${_post.text}',
                  subject: _post.title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Asks before deleting your own post, then leaves the page if it went.
  Future<void> _confirmDelete() async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.pdDeletePost,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(t.pdAreYouSureYou2, style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.pdCancel,
                style: GoogleFonts.manrope(color: BlushyColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.pdDelete,
                style: GoogleFonts.manrope(color: BlushyColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _redditService.deletePost(_post.postId);
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildCommentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.of(context).pdComments,
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        PopupMenuButton<String>(
          initialValue: _commentSort,
          onSelected: (val) {
            setState(() {
              _commentSort = val;
            });
            _loadPostDetails();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'top', child: Text('Top Comments')),
            const PopupMenuItem(value: 'new', child: Text('Newest')),
            const PopupMenuItem(value: 'controversial', child: Text('Controversial')),
          ],
          child: Row(
            children: [
              Text(
                _commentSort == 'top'
                    ? 'Top'
                    : _commentSort == 'new'
                        ? 'New'
                        : 'Controversial',
                style: GoogleFonts.manrope(height: 1.5, 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: BlushyColors.primary),
            ],
          ),
        )
      ],
    );
  }

  List<Widget> _buildCommentTreeWidgets(List<CommunityComment> comments, int depth) {
    final List<Widget> list = [];
    for (final comment in comments) {
      list.add(
        _CommentWidget(
          comment: comment,
          depth: depth,
          currentUserId: _currentUserId,
          onReply: (c) {
            setState(() {
              _replyTarget = c;
            });
            _focusNode.requestFocus();
          },
          onVote: (c, val) => _voteComment(c, val),
          onDelete: (c) => _deleteComment(c),
          onAuthorTap: (authorId) => _showProfile(authorId),
        ),
      );
      if (comment.replies.isNotEmpty) {
        list.addAll(_buildCommentTreeWidgets(comment.replies, depth + 1));
      }
    }
    return list;
  }

  Widget _buildCommentComposer() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyTarget != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: BlushyColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: BlushyColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to @${_replyTarget!.authorName}',
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyTarget = null;
                      });
                    },
                    child: const Icon(Icons.close_rounded, size: 16, color: BlushyColors.primary),
                  )
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EFE6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 13.5, color: BlushyColors.text),
                    decoration: InputDecoration(
                      hintText: _replyTarget != null ? 'Write a reply...' : 'Add a comment...',
                      hintStyle: GoogleFonts.manrope(height: 1.5, fontSize: 13, color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: BlushyColors.primary, strokeWidth: 2),
                    )
                  : InkWell(
                      onTap: _submitComment,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: BlushyColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      ),
                    )
            ],
          ),
        ],
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

class _CommentWidget extends StatelessWidget {
  final CommunityComment comment;
  final int depth;
  final String currentUserId;
  final Function(CommunityComment) onReply;
  final Function(CommunityComment, int) onVote;
  final Function(CommunityComment) onDelete;
  final Function(String) onAuthorTap;

  const _CommentWidget({
    required this.comment,
    required this.depth,
    required this.currentUserId,
    required this.onReply,
    required this.onVote,
    required this.onDelete,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnComment = comment.authorId == currentUserId;
    final isDeleted = comment.text == '[deleted]';

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0 * depth,
        bottom: 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: depth > 0
              ? const Border(
                  left: BorderSide(
                    color: BlushyColors.border,
                    width: 1.5,
                  ),
                )
              : null,
        ),
        padding: EdgeInsets.only(
          left: depth > 0 ? 12.0 : 0,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BlushyColors.border.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author & Date
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5EFE6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isDeleted ? '?' : (comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : 'U'),
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isDeleted ? null : () => onAuthorTap(comment.authorId),
                    child: Text(
                      isDeleted ? '[deleted]' : comment.authorName,
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDeleted ? BlushyColors.secondaryText : BlushyColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeAgoFormatted(comment.createdAt),
                    style: GoogleFonts.manrope(height: 1.5, 
                      fontSize: 10,
                      color: BlushyColors.secondaryText.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (isOwnComment && !isDeleted)
                    GestureDetector(
                      onTap: () => onDelete(comment),
                      child: const Icon(Icons.delete_outline_rounded, color: BlushyColors.primary, size: 16),
                    )
                ],
              ),
              const SizedBox(height: 8),

              // Comment text
              Text(
                comment.text,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: isDeleted ? BlushyColors.secondaryText : BlushyColors.text,
                  height: 1.45,
                ),
              ),
              // Same notice posts carry, for the same reason: a reply about a
              // health topic is not clinical advice either (spec section 12).
              if (!isDeleted) ModerationNotice(notice: comment.moderationNotice),
              const SizedBox(height: 10),

              // Actions
              if (!isDeleted)
                Row(
                  children: [
                    // Vote Controls
                    GestureDetector(
                      onTap: () => onVote(comment, 1),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: comment.userVote == 1 ? BlushyColors.primary : BlushyColors.secondaryText,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Text(
                        '${comment.score}',
                        style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: comment.userVote != 0 ? BlushyColors.primary : comment.userVote == -1 ? BlushyColors.accent : BlushyColors.text,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onVote(comment, -1),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: comment.userVote == -1 ? BlushyColors.accent : BlushyColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Reply Button
                    GestureDetector(
                      onTap: () => onReply(comment),
                      child: Row(
                        children: [
                          const Icon(Icons.reply_rounded, size: 14, color: BlushyColors.secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: GoogleFonts.manrope(height: 1.5, 
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: BlushyColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgoFormatted(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    }
    return '1m';
  }
}
