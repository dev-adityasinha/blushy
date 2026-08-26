import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/reddit_community_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _redditService = RedditCommunityService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text.startsWith('#') ? text : '#$text');
        _tagController.clear();
      });
    }
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a post title')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final post = await _redditService.createPost(title, body, _tags);

      if (post != null) {
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate post created successfully
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to publish post. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: BlushyColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create a Post',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: BlushyColors.text,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Publish',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              TextField(
                controller: _titleController,
                maxLines: null,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
                decoration: InputDecoration(
                  hintText: 'An interesting title...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: BlushyColors.secondaryText.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: BlushyColors.border, height: 16),
              
              // Body Field
              TextField(
                controller: _bodyController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  color: BlushyColors.text,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts, experiences, or questions...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14.5,
                    color: BlushyColors.secondaryText.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 32),
              
              // Flairs / Tags Input
              Text(
                'Add Flairs / Tags',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
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
                        controller: _tagController,
                        onSubmitted: (_) => _addTag(),
                        style: GoogleFonts.poppins(fontSize: 13.5, color: BlushyColors.text),
                        decoration: InputDecoration(
                          hintText: 'e.g., Luteal, MoodSwings, SleepTips',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 12.5, 
                            color: BlushyColors.secondaryText.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _addTag,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EFE6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded, color: BlushyColors.secondaryText),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              
              // Display Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return InputChip(
                    label: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF5EFE6),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: BlushyColors.secondaryText),
                    onDeleted: () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
