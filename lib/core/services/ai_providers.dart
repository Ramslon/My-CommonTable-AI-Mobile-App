enum AiProvider { local, openai, huggingface, gemini, gpt5mini }

extension AiProviderExt on AiProvider {
  String get id {
    switch (this) {
      case AiProvider.openai:
        return 'openai';
      case AiProvider.huggingface:
        return 'huggingface';
      case AiProvider.gemini:
        return 'gemini';
      case AiProvider.gpt5mini:
        return 'gpt5-mini';
      default:
        return 'local';
    }
  }
}
