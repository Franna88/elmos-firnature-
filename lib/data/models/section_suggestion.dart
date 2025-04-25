class SectionSuggestion {
  final String name;
  final String description;
  final bool isDefault;

  const SectionSuggestion({
    required this.name,
    required this.description,
    this.isDefault = false,
  });
}

// List of common section suggestions that can be used in the UI
final List<SectionSuggestion> commonSectionSuggestions = [
  const SectionSuggestion(
    name: 'Tools',
    description: 'List of tools required for this procedure',
    isDefault: true,
  ),
  const SectionSuggestion(
    name: 'Safety',
    description: 'Safety requirements and gear needed',
    isDefault: true,
  ),
  const SectionSuggestion(
    name: 'Cautions',
    description: 'Warnings and cautions to be aware of',
    isDefault: true,
  ),
  const SectionSuggestion(
    name: 'Steps',
    description: 'Procedure steps to follow',
    isDefault: true,
  ),
  const SectionSuggestion(
    name: 'Materials',
    description: 'Materials required for this procedure',
  ),
  const SectionSuggestion(
    name: 'Prerequisites',
    description: 'Things to prepare before starting',
  ),
  const SectionSuggestion(
    name: 'References',
    description: 'External documentation or references',
  ),
  const SectionSuggestion(
    name: 'Quality Control',
    description: 'Quality control checkpoints',
  ),
  const SectionSuggestion(
    name: 'Troubleshooting',
    description: 'Common issues and solutions',
  ),
  const SectionSuggestion(
    name: 'Clean-up',
    description: 'Clean-up procedures after completion',
  ),
];
