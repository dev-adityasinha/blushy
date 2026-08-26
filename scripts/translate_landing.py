#!/usr/bin/env python3
"""Translate landing page text keys to all 6 languages using deep-translator."""

import sys
import io

from deep_translator import GoogleTranslator

# English landing page keys and values
landing_keys = {
    'landing_badge': 'Your gentle wellness companion',
    'landing_meet_blushy': 'Meet Blushy',
    'landing_tagline': 'your gentle cycle companion',
    'landing_description': 'Track, understand, and care for your body beautifully. A safe space designed with love, for you.',
    'landing_start_journey': 'Start Your Journey',
    'landing_learn_more': 'Learn More',
    'landing_features_label': 'Features',
    'landing_features_title': 'Everything you need, beautifully designed',
    'landing_features_subtitle': 'Thoughtful features crafted with care to support your journey.',
    'landing_feature_cycle_title': 'Cycle Tracking',
    'landing_feature_cycle_desc': 'Effortlessly track your cycle with beautiful visualizations and accurate predictions.',
    'landing_feature_mood_title': 'Mood Insights',
    'landing_feature_mood_desc': 'Understand your emotional patterns and discover what makes you feel your best.',
    'landing_feature_ai_title': 'AI Companion',
    'landing_feature_ai_desc': 'Your caring AI friend who understands, supports, and celebrates with you.',
    'landing_how_label': 'How It Works',
    'landing_how_title': 'Simple, intuitive, and empowering',
    'landing_how_step1_title': 'Track Your Cycle',
    'landing_how_step1_desc': 'Log your period and symptoms easily',
    'landing_how_step2_title': 'Get Insights',
    'landing_how_step2_desc': 'Understand your patterns and predictions',
    'landing_how_step3_title': 'Feel Supported',
    'landing_how_step3_desc': 'Chat with Sia, your AI companion',
    'landing_testimonials_label': 'Testimonials',
    'landing_testimonials_title': 'Loved by thousands',
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
    'footer_copyright': '2026 Blushy. All rights reserved. Made with love.',
}

# Target languages
langs = {
    'hi': 'hindi',
    'bn': 'bengali',
    'ta': 'tamil',
    'te': 'telugu',
    'mr': 'marathi',
    'kn': 'kannada',
}

# Write output to file to avoid console encoding issues
output_path = 'scripts/translations_output.txt'
with io.open(output_path, 'w', encoding='utf-8') as f:
    for code, name in langs.items():
        f.write(f"\n# {name} ({code}) translations\n")
        lang_translator = GoogleTranslator(source='en', target=code)
        for key, text in landing_keys.items():
            try:
                translated = lang_translator.translate(text)
                if translated:
                    translated = translated.replace("\\", "\\\\").replace("'", "\\'")
                else:
                    translated = text
                f.write(f"      '{key}': '{translated}',\n")
            except Exception as e:
                f.write(f"      # {key}: ERROR - {e}\n")
                f.write(f"      '{key}': '{text}',\n")
        f.write("\n")
    f.flush()

print(f"Done! Wrote translations to {output_path}")
print(f"Translations generated for: {', '.join(langs.keys())}")
