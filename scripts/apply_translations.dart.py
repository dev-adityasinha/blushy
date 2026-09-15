#!/usr/bin/env python3
"""Replace English landing page keys in app_text.dart with actual translated values."""
import re

# Read the translations output
with open('scripts/translations_output.txt', 'r', encoding='utf-8') as f:
    content = f.read()

# Parse the translations into a dict: {lang: {key: value}}
sections = content.strip().split('\n\n')
translations = {}
for section in sections:
    lines = section.strip().split('\n')
    if not lines:
        continue
    # First line looks like "# hindi (hi) translations"
    first_line = lines[0].strip()
    match = re.match(r'^#\s+\w+\s+\((\w+)\)\s+translations$', first_line)
    if not match:
        continue
    lang = match.group(1)
    trans = {}
    for line in lines[1:]:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        kv_match = re.match(r"'([^']+)':\s*'([^']*)',?$", line)
        if kv_match:
            key = kv_match.group(1)
            value = kv_match.group(2)
            trans[key] = value
    translations[lang] = trans

# Read the app_text.dart file
with open('website blushy/lib/app/app_text.dart', 'r', encoding='utf-8') as f:
    dart_content = f.read()

# For each language, replace the landing page block
# The landing page keys start with 'landing_badge', 'footer_product', etc.
# They are grouped together with a comment "// Landing page" before them
landing_keys = [
    'landing_badge', 'landing_meet_blushy', 'landing_tagline', 'landing_description',
    'landing_start_journey', 'landing_learn_more', 'landing_features_label',
    'landing_features_title', 'landing_features_subtitle', 'landing_feature_cycle_title',
    'landing_feature_cycle_desc', 'landing_feature_mood_title', 'landing_feature_mood_desc',
    'landing_feature_ai_title', 'landing_feature_ai_desc', 'landing_how_label',
    'landing_how_title', 'landing_how_step1_title', 'landing_how_step1_desc',
    'landing_how_step2_title', 'landing_how_step2_desc', 'landing_how_step3_title',
    'landing_how_step3_desc', 'landing_testimonials_label', 'landing_testimonials_title',
    'landing_cta_title', 'landing_cta_desc', 'landing_download', 'footer_product',
    'footer_company', 'footer_legal', 'footer_pricing', 'footer_about', 'footer_blog',
    'footer_privacy', 'footer_terms', 'footer_copyright',
]

# Build replacement lines for each language
for lang_code, trans in translations.items():
    print(f"Replacing {lang_code}...")
    
    # For each key, find and replace its value in the dart file
    for key in landing_keys:
        if key in trans:
            translated_val = trans[key]
            # Escape the translated value for Dart strings (escape backticks, $ in some cases)
            escaped_val = translated_val.replace("'", "\\'")
            
            # Find the current line in the dart file for this language and key
            # Pattern: within the lang_code section, find the key line
            # We need to be careful to only replace within the correct language section
            
            # Build regex to find the key within the specific language section
            # This is tricky because we need to scope it. Let's use a simpler approach:
            # Find the key line that is between the lang_code section start and the next section start
            
            # Simple approach: find all lines with this key and replace the one in the right language section
            # We'll do a section-based approach
            
            old_pattern = f"'{key}': '{trans.get(key, '')}'"
            
            # Actually, we know the old value is English (the fallback we added)
            # Let's find the English value to replace
            # The English values were added as fallback, e.g.:
            # 'landing_badge': 'Your gentle wellness companion',
            
            # Let me just read app_text.dart and find what's currently there for each key in each lang
            
# Better approach: read the file, find each language section, and replace the landing page block
with open('website blushy/lib/app/app_text.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the range of each language section
lang_section_ranges = {}
current_lang = None
start_idx = None

for i, line in enumerate(lines):
    # Match 'hi': { or 'bn': { etc.
    lang_match = re.match(r"^\s+'(\w{2})':\s*\{", line)
    if lang_match:
        if current_lang:
            lang_section_ranges[current_lang] = (start_idx, i)
        current_lang = lang_match.group(1)
        start_idx = i
    # Match closing }, for the section (but not for nested ones)
    # This is tricky - let's use a simpler approach

# Let's just do direct line-by-line replacement for each key in each language
# by finding the key line that falls within each language section

# Actually, let me try a different approach. Let me reconstruct the file.
# I'll read the file, find each language's landing page section, and replace the values.

# The simplest approach: line by line replacement within the correct language section.
# I'll find the index range for each language, then within that range replace key-value pairs.

# Find language sections by matching the opening pattern
lang_positions = []
for i, line in enumerate(lines):
    lang_match = re.match(r"^\s+'(\w{2})':\s*\{", line)
    if lang_match:
        lang_positions.append((lang_match.group(1), i))

# Now find the range for each language
for idx, (lang, start) in enumerate(lang_positions):
    end = lang_positions[idx + 1][1] if idx + 1 < len(lang_positions) else len(lines)
    lang_section_ranges[lang] = (start, end)

# Now replace key-value pairs within each language section
for lang_code, (section_start, section_end) in lang_section_ranges.items():
    if lang_code not in translations:
        continue
    print(f"Processing {lang_code} section (lines {section_start}-{section_end})...")
    
    trans = translations[lang_code]
    
    for key in landing_keys:
        if key not in trans:
            continue
        
        translated_val = trans[key]
        escaped_val = translated_val.replace("'", "\\'")
        
        # Search for the key line within this section
        for i in range(section_start, section_end):
            line = lines[i]
            # Match: 'key': 'current_value',
            kv_match = re.match(r"(\s*'{}':\s*)'([^']*)'(,?)".format(re.escape(key)), line)
            if kv_match:
                indent = kv_match.group(1)
                comma = kv_match.group(3)
                lines[i] = f"{indent}'{escaped_val}'{comma}\n"
                break

# Write the updated content
with open('website blushy/lib/app/app_text.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\nDone! Updated app_text.dart with translations.")
