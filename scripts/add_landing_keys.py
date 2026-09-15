#!/usr/bin/env python3
"""Add landing page translation keys to all language sections in app_text.dart."""

# Read the Dart file
with open('website blushy/lib/app/app_text.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Landing page keys to add (with English text as placeholder)
landing_keys_block = """      // Landing page
      'landing_badge': 'Your gentle wellness companion',
      'landing_meet_blushy': 'Meet Blushy',
      'landing_tagline': 'your gentle cycle companion',
      'landing_description': 'Track, understand, and care for your body beautifully.\\nA safe space designed with love, for you.',
      'landing_start_journey': 'Start Your Journey',
      'landing_learn_more': 'Learn More',
      'landing_features_label': 'Features',
      'landing_features_title': 'Everything you need, beautifully designed \u2764\ufe0f',
      'landing_features_subtitle': 'Thoughtful features crafted with care to support your journey.',
      'landing_feature_cycle_title': 'Cycle Tracking',
      'landing_feature_cycle_desc': 'Effortlessly track your cycle with beautiful visualizations and accurate predictions.',
      'landing_feature_mood_title': 'Mood Insights',
      'landing_feature_mood_desc': 'Understand your emotional patterns and discover what makes you feel your best.',
      'landing_feature_ai_title': 'AI Companion',
      'landing_feature_ai_desc': 'Your caring AI friend who understands, supports, and celebrates with you.',
      'landing_how_label': 'How It Works',
      'landing_how_title': 'Simple, intuitive, and empowering \U0001f338',
      'landing_how_step1_title': 'Track Your Cycle',
      'landing_how_step1_desc': 'Log your period and symptoms easily',
      'landing_how_step2_title': 'Get Insights',
      'landing_how_step2_desc': 'Understand your patterns and predictions',
      'landing_how_step3_title': 'Feel Supported',
      'landing_how_step3_desc': 'Chat with Sia, your AI companion',
      'landing_testimonials_label': 'Testimonials',
      'landing_testimonials_title': 'Loved by thousands \U0001f497',
      'landing_cta_title': 'Ready to start your journey?',
      'landing_cta_desc': 'Join thousands of users who trust Blushy with their wellness.',
      'landing_download': 'Download Now',
      'footer_product': 'Product',
      'footer_company': 'Company',
      'footer_legal': 'Legal',
      'footer_pricing': 'Pricing',
      'footer_about': 'About Us',
      'footer_blog': 'Blog',
      'footer_privacy': 'Privacy',
      'footer_terms': 'Terms',
      'footer_copyright': '\u00a9 2026 Blushy. All rights reserved. Made with \U0001f497',
"""

# Language codes to add keys to (excluding 'en' which already has them)
lang_codes = ['hi', 'bn', 'ta', 'te', 'mr', 'kn']

# Process each language section
for code in lang_codes:
    # Find the section start: line containing f"'{code}': {{"
    section_start = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(f"'{code}':") and stripped.endswith('{'):
            section_start = i
            break
    
    if section_start is None:
        print(f"Could not find start of '{code}' section")
        continue
    
    # Find the closing "}," for this section by counting brace depth
    # The opening brace is on section_start line
    depth = 0
    section_end = None
    for j in range(section_start, len(lines)):
        stripped = lines[j].strip()
        # Count opening braces
        depth += stripped.count('{')
        # Count closing braces (ignore } within strings)
        depth -= stripped.count('}')
        
        if depth == 0 and j > section_start:
            # This line has the closing "},"
            section_end = j
            break
    
    if section_end is None:
        print(f"Could not find end of '{code}' section")
        continue
    
    # Check if landing keys already exist in this section
    already_has = any('landing_badge' in lines[k] for k in range(section_start, section_end + 1))
    if already_has:
        print(f"'{code}' section already has landing keys, skipping")
        continue
    
    # Insert the landing keys block before the closing line
    insert_line = section_end  # Insert before the closing "},"
    
    # Build the new lines
    new_lines = lines[:insert_line]
    new_lines.append(landing_keys_block)
    new_lines.extend(lines[insert_line:])
    lines = new_lines
    
    print(f"Added keys to '{code}' section (inserted before line {insert_line})")

# Write the file back
with open('website blushy/lib/app/app_text.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\nDone! Added landing page keys to all language sections.")
