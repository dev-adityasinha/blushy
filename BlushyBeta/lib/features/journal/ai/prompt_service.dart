class ReflectionPrompt {
  final String text;
  final String category;

  const ReflectionPrompt({required this.text, required this.category});
}

class PromptService {
  final List<ReflectionPrompt> _prompts = const [
    ReflectionPrompt(text: 'What made you smile today?', category: 'Joy'),
    ReflectionPrompt(text: 'What\'s one thing you\'re grateful for?', category: 'Gratitude'),
    ReflectionPrompt(text: 'What\'s something you learned recently?', category: 'Growth'),
    ReflectionPrompt(text: 'What challenged you today, and how did you respond?', category: 'Reflection'),
    ReflectionPrompt(text: 'How did you take care of your peace today?', category: 'Self-Care'),
  ];

  List<ReflectionPrompt> getPrompts() {
    return _prompts;
  }
}
