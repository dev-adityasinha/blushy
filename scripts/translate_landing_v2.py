#!/usr/bin/env python3
"""Translate landing page text to 6 Indian languages using deep-translator with retries."""
import json
import time
import sys
from deep_translator import GoogleTranslator, exceptions

# Define the landing page keys and their English text
landing_keys = {
    'landing_badge': 'Your gentle wellness companion',
    'landing_meet_blushy': 'Meet Blushy',
    'landing_tagline': 'your gentle cycle companion',
    'landing_description': 'Track, understand, and care for your body beautifully.\nA safe space designed with love, for you.',
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
}

langs = {
    'hi': 'Hindi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'kn': 'Kannada',
}

def translate_with_retry(text, target_lang, max_retries=3):
    for attempt in range(max_retries):
        try:
            translator = GoogleTranslator(source='en', target=target_lang)
            result = translator.translate(text)
            if result:
                return result
        except Exception as e:
            print(f"  Attempt {attempt+1} failed: {e}", file=sys.stderr)
            if attempt < max_retries - 1:
                wait = 2 * (attempt + 1)
                print(f"  Waiting {wait}s before retry...", file=sys.stderr)
                time.sleep(wait)
    return None

results = {}

for code, name in langs.items():
    print(f"\n=== Translating to {name} ({code}) ===", file=sys.stderr)
    results[code] = {}
    for key, text in landing_keys.items():
        translated = translate_with_retry(text, code)
        if translated:
            # Escape single quotes for Dart
            escaped = translated.replace("\\", "\\\\").replace("'", "\\'")
            results[code][key] = escaped
            print(f"  {key}: OK", file=sys.stderr)
        else:
            results[code][key] = text  # fallback to English
            print(f"  {key}: FAILED (using English)", file=sys.stderr)
        time.sleep(0.3)  # Rate limiting

# Save results to a JSON file for inspection
output = {'en': {k: v.replace("'", "\\'").replace("\\", "\\\\") for k, v in landing_keys.items()}}
output.update(results)

with open('scripts/translations_output.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

print("\nDone! Results saved to scripts/translations_output.json")
print("Here are the Dart-formatted translations:\n")

for code in ['hi', 'bn', 'ta', 'te', 'mr', 'kn']:
    print(f"      // Landing page - {langs[code]}")
    for key in landing_keys:
        val = results[code].get(key, landing_keys[key])
        print(f"      '{key}': '{val}',")
    print()
