import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart' hide BlushyColors;
import '../../../theme/colors.dart';
import 'note_page_background.dart';
import 'note_style.dart';

/// Choosing the page before writing on it.
///
/// The papers existed already, but behind a toolbar icon *inside* the editor:
/// you wrote first on the plain default and only found the rest if you went
/// looking. Writing starts here instead -- pick the page, then write on it.
///
/// Every tile is drawn by the same [NotePageBackground] the editor and the
/// list card use, so what is tapped is exactly what opens. Nothing here is a
/// picture of a template.
class NoteTemplatePickerScreen extends StatelessWidget {
  const NoteTemplatePickerScreen({super.key});

  /// The papers, in the order the enum declares them: the four plain rulings
  /// first, then the decorated ones.
  static List<NoteTemplate> get templates => NoteTemplate.values;

  @override
  Widget build(BuildContext context) {
    final padding = BlushyTheme.getPagePadding(context);

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.text),
        title: Text(
          'Choose a page',
          style: GoogleFonts.manrope(
            height: 1.5,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            // Roughly a page's proportions, plus room for the name beneath.
            childAspectRatio: 0.66,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) => _tile(context, templates[index]),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, NoteTemplate template) {
    // The default paper colour, which is what a new entry starts on. The ink
    // is read off it so the ruling on the plain papers is visible.
    const style = NoteStyle();
    final ink = NoteBackgrounds.inkFor(style.background);
    final radius = BorderRadius.circular(BlushyTheme.radius);

    // The whole tile is the target, name included -- the name is what people
    // reach for when the papers look alike at this size.
    return Semantics(
      button: true,
      label: template.label,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(template),
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: BlushyColors.border),
                  color: template.isDecorated
                      ? Color(template.ground!)
                      : style.backgroundColor,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  // Drawn small. `lineHeight` scales with it so a ruled page
                  // reads as ruled rather than as four fat stripes.
                  child: NotePageBackground(
                    style: style.copyWith(template: template),
                    ink: ink,
                    lineHeight: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                height: 1.4,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: BlushyColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
