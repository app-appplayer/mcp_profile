/// ProfileRenderer Tests
///
/// Tests for ProfileRenderer, ProfileRenderOptions, and RenderedSection.
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  group('ProfileRenderOptions', () {
    test('creates with default values', () {
      const options = ProfileRenderOptions();

      expect(options.ordering, equals(SectionOrdering.byPriority));
      expect(options.sectionSeparator, equals('\n\n'));
      expect(options.childSeparator, equals('\n'));
      expect(options.wrapSections, isFalse);
      expect(options.includeDisabled, isFalse);
    });

    test('creates with custom values', () {
      const options = ProfileRenderOptions(
        ordering: SectionOrdering.byType,
        sectionSeparator: '---',
        childSeparator: '; ',
        wrapSections: true,
        sectionHeaderFormat: '# {name}',
        sectionFooterFormat: '---',
        includeDisabled: true,
      );

      expect(options.ordering, equals(SectionOrdering.byType));
      expect(options.sectionSeparator, equals('---'));
      expect(options.wrapSections, isTrue);
      expect(options.includeDisabled, isTrue);
    });

    test('copyWith creates modified copy', () {
      const original = ProfileRenderOptions(
        ordering: SectionOrdering.byPriority,
        wrapSections: false,
      );

      final modified = original.copyWith(
        ordering: SectionOrdering.byType,
        wrapSections: true,
      );

      expect(original.ordering, equals(SectionOrdering.byPriority));
      expect(modified.ordering, equals(SectionOrdering.byType));
      expect(original.wrapSections, isFalse);
      expect(modified.wrapSections, isTrue);
    });

    test('copyWith preserves unmodified values', () {
      const original = ProfileRenderOptions(
        sectionSeparator: '###',
        childSeparator: '---',
      );

      final modified = original.copyWith(sectionSeparator: '***');

      expect(modified.sectionSeparator, equals('***'));
      expect(modified.childSeparator, equals('---'));
    });
  });

  group('RenderedSection', () {
    test('creates with required fields', () {
      const section = RenderedSection(
        name: 'system',
        type: SectionType.system,
        content: 'System prompt content',
        priority: 100,
      );

      expect(section.name, equals('system'));
      expect(section.type, equals(SectionType.system));
      expect(section.content, equals('System prompt content'));
      expect(section.priority, equals(100));
    });

    test('toString returns content', () {
      const section = RenderedSection(
        name: 'test',
        type: SectionType.custom,
        content: 'Test content',
        priority: 0,
      );

      expect(section.toString(), equals('Test content'));
    });
  });

  group('ProfileRenderer', () {
    late ProfileRenderer renderer;

    setUp(() {
      renderer = const ProfileRenderer();
    });

    test('renders empty profile', () async {
      const profile = Profile(
        id: 'empty',
        name: 'Empty Profile',
      );

      final result = await renderer.render(profile);

      expect(result, isEmpty);
    });

    test('renders single section', () async {
      const profile = Profile(
        id: 'single',
        name: 'Single Section',
        sections: [
          ProfileSection(
            name: 'system',
            type: SectionType.system,
            content: 'You are a helpful assistant.',
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, equals('You are a helpful assistant.'));
    });

    test('renders multiple sections with separator', () async {
      const profile = Profile(
        id: 'multi',
        name: 'Multi Section',
        sections: [
          ProfileSection(
            name: 'system',
            type: SectionType.system,
            content: 'System prompt',
            priority: 100,
          ),
          ProfileSection(
            name: 'context',
            type: SectionType.context,
            content: 'Context info',
            priority: 50,
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('System prompt'));
      expect(result, contains('Context info'));
    });

    test('sorts sections by priority', () async {
      const profile = Profile(
        id: 'sorted',
        name: 'Sorted',
        sections: [
          ProfileSection(name: 'low', type: SectionType.custom, content: 'LOW', priority: 10),
          ProfileSection(name: 'high', type: SectionType.custom, content: 'HIGH', priority: 100),
          ProfileSection(name: 'mid', type: SectionType.custom, content: 'MID', priority: 50),
        ],
      );

      final result = await renderer.render(profile);

      expect(result.indexOf('HIGH'), lessThan(result.indexOf('MID')));
      expect(result.indexOf('MID'), lessThan(result.indexOf('LOW')));
    });

    test('filters disabled sections', () async {
      const profile = Profile(
        id: 'filtered',
        name: 'Filtered',
        sections: [
          ProfileSection(name: 'enabled', type: SectionType.custom, content: 'ENABLED', enabled: true),
          ProfileSection(name: 'disabled', type: SectionType.custom, content: 'DISABLED', enabled: false),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('ENABLED'));
      expect(result, isNot(contains('DISABLED')));
    });

    test('evaluates section conditions with true', () async {
      const profile = Profile(
        id: 'conditional',
        name: 'Conditional',
        sections: [
          ProfileSection(
            name: 'always',
            type: SectionType.custom,
            content: 'ALWAYS',
          ),
          ProfileSection(
            name: 'conditional',
            type: SectionType.custom,
            content: 'CONDITIONAL',
            condition: 'true',
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('ALWAYS'));
      expect(result, contains('CONDITIONAL'));
    });

    test('evaluates section conditions with false', () async {
      const profile = Profile(
        id: 'conditional-false',
        name: 'Conditional False',
        sections: [
          ProfileSection(
            name: 'always',
            type: SectionType.custom,
            content: 'ALWAYS',
          ),
          ProfileSection(
            name: 'never',
            type: SectionType.custom,
            content: 'NEVER',
            condition: 'false',
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('ALWAYS'));
      expect(result, isNot(contains('NEVER')));
    });

    test('renderSections returns structured list', () async {
      const profile = Profile(
        id: 'structured',
        name: 'Structured',
        sections: [
          ProfileSection(name: 'sys', type: SectionType.system, content: 'System', priority: 100),
          ProfileSection(name: 'ctx', type: SectionType.context, content: 'Context', priority: 50),
        ],
      );

      final sections = await renderer.renderSections(profile);

      expect(sections.length, equals(2));
      expect(sections.first.name, equals('sys'));
      expect(sections.first.priority, equals(100));
    });

    test('processes template expressions with literals', () async {
      const profile = Profile(
        id: 'template',
        name: 'Template',
        sections: [
          ProfileSection(
            name: 'greeting',
            type: SectionType.custom,
            content: r'Result: ${1 + 2}!',
          ),
        ],
      );

      final result = await renderer.render(profile);

      // Expression evaluator returns numbers as doubles
      expect(result, contains('Result: 3'));
    });

    test('processes double brace expressions with literals', () async {
      const profile = Profile(
        id: 'braces',
        name: 'Braces',
        sections: [
          ProfileSection(
            name: 'calc',
            type: SectionType.custom,
            content: 'Sum: {{5 * 3}}',
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('Sum: 15'));
    });

    test('handles template without expressions', () async {
      const profile = Profile(
        id: 'no-template',
        name: 'No Template',
        sections: [
          ProfileSection(
            name: 'plain',
            type: SectionType.custom,
            content: 'Plain text without any expressions',
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, equals('Plain text without any expressions'));
    });

    test('renders with wrapping', () async {
      const options = ProfileRenderOptions(
        wrapSections: true,
        sectionHeaderFormat: '## {name}',
        sectionFooterFormat: '',
      );
      final wrappingRenderer = ProfileRenderer(options: options);

      const profile = Profile(
        id: 'wrapped',
        name: 'Wrapped',
        sections: [
          ProfileSection(
            name: 'system',
            type: SectionType.system,
            content: 'System prompt',
          ),
        ],
      );

      final result = await wrappingRenderer.render(profile);

      expect(result, contains('## system'));
      expect(result, contains('System prompt'));
    });

    test('renders child sections', () async {
      const profile = Profile(
        id: 'nested',
        name: 'Nested',
        sections: [
          ProfileSection(
            name: 'parent',
            type: SectionType.context,
            content: 'Parent content',
            children: [
              ProfileSection(
                name: 'child1',
                type: SectionType.custom,
                content: 'Child 1',
              ),
              ProfileSection(
                name: 'child2',
                type: SectionType.custom,
                content: 'Child 2',
              ),
            ],
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('Parent content'));
      expect(result, contains('Child 1'));
      expect(result, contains('Child 2'));
    });

    test('filters disabled child sections', () async {
      const profile = Profile(
        id: 'nested-filtered',
        name: 'Nested Filtered',
        sections: [
          ProfileSection(
            name: 'parent',
            type: SectionType.context,
            content: 'Parent',
            children: [
              ProfileSection(name: 'enabled', type: SectionType.custom, content: 'ENABLED', enabled: true),
              ProfileSection(name: 'disabled', type: SectionType.custom, content: 'DISABLED', enabled: false),
            ],
          ),
        ],
      );

      final result = await renderer.render(profile);

      expect(result, contains('ENABLED'));
      expect(result, isNot(contains('DISABLED')));
    });

    test('sorts by type ordering', () async {
      const options = ProfileRenderOptions(
        ordering: SectionOrdering.byType,
      );
      final typeRenderer = ProfileRenderer(options: options);

      const profile = Profile(
        id: 'type-sorted',
        name: 'Type Sorted',
        sections: [
          ProfileSection(name: 'ctx', type: SectionType.context, content: 'CONTEXT'),
          ProfileSection(name: 'sys', type: SectionType.system, content: 'SYSTEM'),
          ProfileSection(name: 'inst', type: SectionType.instructions, content: 'INSTRUCTIONS'),
        ],
      );

      final result = await typeRenderer.render(profile);

      expect(result.indexOf('SYSTEM'), lessThan(result.indexOf('INSTRUCTIONS')));
      expect(result.indexOf('INSTRUCTIONS'), lessThan(result.indexOf('CONTEXT')));
    });

    test('keeps original order with asIs ordering', () async {
      const options = ProfileRenderOptions(
        ordering: SectionOrdering.asIs,
      );
      final asIsRenderer = ProfileRenderer(options: options);

      const profile = Profile(
        id: 'as-is',
        name: 'As Is',
        sections: [
          ProfileSection(name: 'first', type: SectionType.custom, content: 'FIRST', priority: 10),
          ProfileSection(name: 'second', type: SectionType.custom, content: 'SECOND', priority: 100),
        ],
      );

      final result = await asIsRenderer.render(profile);

      expect(result.indexOf('FIRST'), lessThan(result.indexOf('SECOND')));
    });

    // =========================================================================
    // D8: Additional coverage tests
    // =========================================================================
    group('_evaluateCondition exception handling', () {
      test('returns false when condition expression throws an exception', () async {
        // Use an invalid expression that will cause the expression parser to throw
        const profile = Profile(
          id: 'bad-cond',
          name: 'Bad Condition',
          sections: [
            ProfileSection(
              name: 'guarded',
              type: SectionType.custom,
              content: 'GUARDED CONTENT',
              condition: '!!!invalid[[[expression',
            ),
            ProfileSection(
              name: 'always',
              type: SectionType.custom,
              content: 'ALWAYS SHOWN',
            ),
          ],
        );

        final result = await renderer.render(profile);

        // Invalid condition should evaluate to false, excluding the section
        expect(result, isNot(contains('GUARDED CONTENT')));
        expect(result, contains('ALWAYS SHOWN'));
      });
    });

    group('_processTemplate with mixed syntax', () {
      test('processes both dollar-brace and double-brace expressions in same template', () async {
        const profile = Profile(
          id: 'mixed-template',
          name: 'Mixed Template',
          sections: [
            ProfileSection(
              name: 'mixed',
              type: SectionType.custom,
              content: r'Dollar: ${2 + 3}, Brace: {{4 * 5}}',
            ),
          ],
        );

        final result = await renderer.render(profile);

        // Both expression types should be evaluated
        expect(result, contains('Dollar: 5'));
        expect(result, contains('Brace: 20'));
      });
    });

    group('_typeOrder for custom SectionType', () {
      test('custom type sorts last when ordering by type', () async {
        const options = ProfileRenderOptions(
          ordering: SectionOrdering.byType,
        );
        final typeRenderer = ProfileRenderer(options: options);

        const profile = Profile(
          id: 'type-order-custom',
          name: 'Type Order Custom',
          sections: [
            ProfileSection(name: 'custom', type: SectionType.custom, content: 'CUSTOM'),
            ProfileSection(name: 'tools', type: SectionType.tools, content: 'TOOLS'),
            ProfileSection(name: 'knowledge', type: SectionType.knowledge, content: 'KNOWLEDGE'),
            ProfileSection(name: 'examples', type: SectionType.examples, content: 'EXAMPLES'),
            ProfileSection(name: 'persona', type: SectionType.persona, content: 'PERSONA'),
            ProfileSection(name: 'constraints', type: SectionType.constraints, content: 'CONSTRAINTS'),
          ],
        );

        final result = await typeRenderer.render(profile);

        // _typeOrder: persona=1, constraints=3, knowledge=5, examples=6, tools=7, custom=8
        expect(result.indexOf('PERSONA'), lessThan(result.indexOf('CONSTRAINTS')));
        expect(result.indexOf('CONSTRAINTS'), lessThan(result.indexOf('KNOWLEDGE')));
        expect(result.indexOf('KNOWLEDGE'), lessThan(result.indexOf('EXAMPLES')));
        expect(result.indexOf('EXAMPLES'), lessThan(result.indexOf('TOOLS')));
        expect(result.indexOf('TOOLS'), lessThan(result.indexOf('CUSTOM')));
      });
    });

    group('wrapping with both header and footer', () {
      test('renders section with both header and footer format', () async {
        const options = ProfileRenderOptions(
          wrapSections: true,
          sectionHeaderFormat: '--- {name} ({type}) ---',
          sectionFooterFormat: '--- end {name} ---',
        );
        final wrappingRenderer = ProfileRenderer(options: options);

        const profile = Profile(
          id: 'wrapped-full',
          name: 'Wrapped Full',
          sections: [
            ProfileSection(
              name: 'intro',
              type: SectionType.persona,
              content: 'I am a persona.',
            ),
          ],
        );

        final result = await wrappingRenderer.render(profile);

        expect(result, contains('--- intro (persona) ---'));
        expect(result, contains('I am a persona.'));
        expect(result, contains('--- end intro ---'));
      });
    });

    group('child sections with condition', () {
      test('filters child sections based on condition evaluation', () async {
        const profile = Profile(
          id: 'child-cond',
          name: 'Child Condition',
          sections: [
            ProfileSection(
              name: 'parent',
              type: SectionType.context,
              content: 'Parent content',
              children: [
                ProfileSection(
                  name: 'child-true',
                  type: SectionType.custom,
                  content: 'CHILD TRUE',
                  condition: 'true',
                ),
                ProfileSection(
                  name: 'child-false',
                  type: SectionType.custom,
                  content: 'CHILD FALSE',
                  condition: 'false',
                ),
              ],
            ),
          ],
        );

        final result = await renderer.render(profile);

        expect(result, contains('CHILD TRUE'));
        expect(result, isNot(contains('CHILD FALSE')));
      });
    });

    group('custom ordering', () {
      test('custom ordering keeps original order like asIs', () async {
        const options = ProfileRenderOptions(
          ordering: SectionOrdering.custom,
        );
        final customRenderer = ProfileRenderer(options: options);

        const profile = Profile(
          id: 'custom-order',
          name: 'Custom Order',
          sections: [
            ProfileSection(name: 'alpha', type: SectionType.custom, content: 'ALPHA', priority: 1),
            ProfileSection(name: 'beta', type: SectionType.custom, content: 'BETA', priority: 100),
          ],
        );

        final result = await customRenderer.render(profile);

        // Custom ordering preserves original order (not by priority)
        expect(result.indexOf('ALPHA'), lessThan(result.indexOf('BETA')));
      });
    });
  });

  group('SectionOrdering', () {
    test('has all expected values', () {
      expect(SectionOrdering.values, containsAll([
        SectionOrdering.byPriority,
        SectionOrdering.byType,
        SectionOrdering.asIs,
        SectionOrdering.custom,
      ]));
    });
  });

  // ===========================================================================
  // Coverage: _evaluateCondition for non-bool return types (lines 127-128)
  // ===========================================================================
  group('_evaluateCondition non-bool return types', () {
    test('condition evaluating to non-zero number is truthy', () async {
      // Expression "42" evaluates to a number (42), which is non-zero => true
      const profile = Profile(
        id: 'num-cond',
        name: 'Number Condition',
        sections: [
          ProfileSection(
            name: 'guarded',
            type: SectionType.custom,
            content: 'GUARDED BY NUMBER',
            condition: '42',
          ),
        ],
      );

      final result = await const ProfileRenderer().render(profile);
      expect(result, contains('GUARDED BY NUMBER'));
    });

    test('condition evaluating to zero number is falsy', () async {
      // Expression "0" evaluates to a number (0), which is zero => false
      const profile = Profile(
        id: 'zero-cond',
        name: 'Zero Condition',
        sections: [
          ProfileSection(
            name: 'guarded',
            type: SectionType.custom,
            content: 'GUARDED BY ZERO',
            condition: '0',
          ),
        ],
      );

      final result = await const ProfileRenderer().render(profile);
      expect(result, isNot(contains('GUARDED BY ZERO')));
    });

    test('condition evaluating to non-empty string is truthy', () async {
      // Expression "'hello'" evaluates to a String "hello", non-empty => true
      const profile = Profile(
        id: 'str-cond',
        name: 'String Condition',
        sections: [
          ProfileSection(
            name: 'guarded',
            type: SectionType.custom,
            content: 'GUARDED BY STRING',
            condition: "'hello'",
          ),
        ],
      );

      final result = await const ProfileRenderer().render(profile);
      expect(result, contains('GUARDED BY STRING'));
    });

    test('condition evaluating to empty string is falsy', () async {
      // Expression "''" evaluates to a String "", empty => false
      const profile = Profile(
        id: 'empty-str-cond',
        name: 'Empty String Condition',
        sections: [
          ProfileSection(
            name: 'guarded',
            type: SectionType.custom,
            content: 'GUARDED BY EMPTY STRING',
            condition: "''",
          ),
        ],
      );

      final result = await const ProfileRenderer().render(profile);
      expect(result, isNot(contains('GUARDED BY EMPTY STRING')));
    });
  });

  // NOTE: _stringify for Map values (lines 235-236) is unreachable through
  // the template expression path because the mcp_bundle ExpressionEvaluator
  // does not return Map values for identifier lookups. Coverage for these
  // lines would require changes to the mcp_bundle expression evaluator.
}
