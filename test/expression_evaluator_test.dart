/// ExpressionEvaluator Tests
///
/// Tests for template expression parsing, evaluation, condition evaluation,
/// variable extraction, validation, and custom function/filter registration.
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

void main() {
  // ===========================================================================
  // ExpressionSyntax Enum Tests
  // ===========================================================================

  group('ExpressionSyntax', () {
    test('has 3 values', () {
      expect(ExpressionSyntax.values.length, equals(3));
    });

    test('contains mustache, dartInterpolation, and both', () {
      expect(ExpressionSyntax.values, contains(ExpressionSyntax.mustache));
      expect(ExpressionSyntax.values,
          contains(ExpressionSyntax.dartInterpolation));
      expect(ExpressionSyntax.values, contains(ExpressionSyntax.both));
    });
  });

  // ===========================================================================
  // ExpressionErrorType Enum Tests
  // ===========================================================================

  group('ExpressionErrorType', () {
    test('has 7 values', () {
      expect(ExpressionErrorType.values.length, equals(7));
    });

    test('contains all expected values', () {
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.syntaxError));
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.unclosedExpression));
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.unknownVariable));
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.unknownFunction));
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.unknownFilter));
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.typeError));
      expect(ExpressionErrorType.values,
          contains(ExpressionErrorType.evaluationError));
    });
  });

  // ===========================================================================
  // ExpressionError Tests
  // ===========================================================================

  group('ExpressionError', () {
    test('creation stores type and message', () {
      final error = ExpressionError(
        type: ExpressionErrorType.syntaxError,
        message: 'unexpected token',
      );

      expect(error.type, equals(ExpressionErrorType.syntaxError));
      expect(error.message, equals('unexpected token'));
      expect(error.position, isNull);
    });

    test('creation with position', () {
      final error = ExpressionError(
        type: ExpressionErrorType.unclosedExpression,
        message: 'missing closing brace',
        position: 42,
      );

      expect(error.position, equals(42));
    });

    test('toString includes type name and message', () {
      final error = ExpressionError(
        type: ExpressionErrorType.unknownVariable,
        message: 'variable "x" not found',
      );

      final str = error.toString();
      expect(str, contains('unknownVariable'));
      expect(str, contains('variable "x" not found'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — evaluate (mustache syntax)
  // ===========================================================================

  group('ExpressionEvaluator evaluate (mustache)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('resolves mustache variable to context value', () {
      final context = ProfileContext(variables: {'name': 'Alice'});

      final result = evaluator.evaluate('Hello, {{name}}!', context);

      expect(result, equals('Hello, Alice!'));
    });

    test('resolves multiple mustache variables', () {
      final context = ProfileContext(variables: {
        'greeting': 'Hi',
        'name': 'Bob',
      });

      final result =
          evaluator.evaluate('{{greeting}}, {{name}}!', context);

      expect(result, equals('Hi, Bob!'));
    });

    test('returns empty string for missing variable', () {
      final context = ProfileContext(variables: {});

      final result = evaluator.evaluate('Value: {{missing}}', context);

      expect(result, equals('Value: '));
    });

    test('handles numeric values', () {
      final context = ProfileContext(variables: {'count': 5});

      final result = evaluator.evaluate('Items: {{count}}', context);

      expect(result, equals('Items: 5'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — evaluate (dart interpolation syntax)
  // ===========================================================================

  group('ExpressionEvaluator evaluate (dart interpolation)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.dartInterpolation);
    });

    test('resolves simple dart variable with \$name', () {
      final context = ProfileContext(variables: {'name': 'Carol'});

      final result = evaluator.evaluate(r'Hello, $name!', context);

      expect(result, equals('Hello, Carol!'));
    });

    test('resolves dart variable with \${name} syntax', () {
      final context = ProfileContext(variables: {'name': 'Dave'});

      final result = evaluator.evaluate(r'Hello, ${name}!', context);

      expect(result, equals('Hello, Dave!'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — evaluate (both syntaxes)
  // ===========================================================================

  group('ExpressionEvaluator evaluate (both)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.both);
    });

    test('resolves both mustache and dart variables in same template', () {
      final context = ProfileContext(variables: {
        'first': 'Eve',
        'last': 'Smith',
      });

      final result =
          evaluator.evaluate(r'Name: {{first}} $last', context);

      expect(result, equals('Name: Eve Smith'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — no expressions
  // ===========================================================================

  group('ExpressionEvaluator evaluate (no expressions)', () {
    test('returns template unchanged when no expressions present', () {
      final evaluator = ExpressionEvaluator();
      final context = ProfileContext(variables: {'name': 'test'});

      final result = evaluator.evaluate('Plain text with no vars', context);

      expect(result, equals('Plain text with no vars'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — filters
  // ===========================================================================

  group('ExpressionEvaluator evaluate (filters)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('upper filter converts to uppercase', () {
      final context = ProfileContext(variables: {'name': 'alice'});

      final result = evaluator.evaluate('{{name | upper}}', context);

      expect(result, equals('ALICE'));
    });

    test('lower filter converts to lowercase', () {
      final context = ProfileContext(variables: {'name': 'ALICE'});

      final result = evaluator.evaluate('{{name | lower}}', context);

      expect(result, equals('alice'));
    });

    test('trim filter removes whitespace', () {
      final context = ProfileContext(variables: {'name': '  Alice  '});

      final result = evaluator.evaluate('{{name | trim}}', context);

      expect(result, equals('Alice'));
    });

    test('capitalize filter uppercases first letter', () {
      final context = ProfileContext(variables: {'name': 'alice'});

      final result = evaluator.evaluate('{{name | capitalize}}', context);

      expect(result, equals('Alice'));
    });

    test('chained filters apply in order', () {
      final context = ProfileContext(variables: {'name': '  alice  '});

      final result =
          evaluator.evaluate('{{name | trim | upper}}', context);

      expect(result, equals('ALICE'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — functions
  // ===========================================================================

  group('ExpressionEvaluator evaluate (functions)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('len function returns string length', () {
      final context = ProfileContext(variables: {'text': 'hello'});

      final result = evaluator.evaluate('{{len(text)}}', context);

      expect(result, equals('5'));
    });

    test('default function returns first arg when non-null', () {
      final context = ProfileContext(variables: {'name': 'Alice'});

      final result =
          evaluator.evaluate('{{default(name, "Unknown")}}', context);

      expect(result, equals('Alice'));
    });

    test('default function returns second arg when first is null', () {
      final context = ProfileContext(variables: {});

      final result =
          evaluator.evaluate('{{default(missing, "Fallback")}}', context);

      expect(result, equals('Fallback'));
    });

    test('join function joins list with separator', () {
      final context =
          ProfileContext(variables: {'items': ['a', 'b', 'c']});

      final result =
          evaluator.evaluate('{{join(items, " - ")}}', context);

      expect(result, equals('a - b - c'));
    });

    test('now function returns non-empty date string', () {
      final context = ProfileContext();

      final result = evaluator.evaluate('{{now()}}', context);

      // now() returns an ISO8601 string
      expect(result, isNotEmpty);
      expect(result, contains('T'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — evaluateCondition
  // ===========================================================================

  group('ExpressionEvaluator evaluateCondition', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('literal "true" returns true', () {
      final context = ProfileContext();
      expect(evaluator.evaluateCondition('true', context), isTrue);
    });

    test('literal "false" returns false', () {
      final context = ProfileContext();
      expect(evaluator.evaluateCondition('false', context), isFalse);
    });

    test('empty string returns true', () {
      final context = ProfileContext();
      expect(evaluator.evaluateCondition('', context), isTrue);
    });

    test('existing truthy variable returns true', () {
      final context = ProfileContext(variables: {'active': true});
      expect(evaluator.evaluateCondition('active', context), isTrue);
    });

    test('non-existing variable returns false', () {
      final context = ProfileContext();
      expect(evaluator.evaluateCondition('missing', context), isFalse);
    });

    test('negation of existing variable returns false', () {
      final context = ProfileContext(variables: {'active': true});
      expect(evaluator.evaluateCondition('!active', context), isFalse);
    });

    test('negation of missing variable returns true', () {
      final context = ProfileContext();
      expect(evaluator.evaluateCondition('!missing', context), isTrue);
    });

    test('equality comparison returns true when equal', () {
      final context = ProfileContext(variables: {'count': 5});
      expect(evaluator.evaluateCondition('count == 5', context), isTrue);
    });

    test('equality comparison returns false when not equal', () {
      final context = ProfileContext(variables: {'count': 3});
      expect(evaluator.evaluateCondition('count == 5', context), isFalse);
    });

    test('inequality comparison returns true when not equal', () {
      final context = ProfileContext(variables: {'count': 3});
      expect(evaluator.evaluateCondition('count != 5', context), isTrue);
    });

    test('greater than comparison', () {
      final context = ProfileContext(variables: {'score': 80});
      expect(
          evaluator.evaluateCondition('score > 70', context), isTrue);
      expect(
          evaluator.evaluateCondition('score > 90', context), isFalse);
    });

    test('less than comparison', () {
      final context = ProfileContext(variables: {'score': 30});
      expect(
          evaluator.evaluateCondition('score < 50', context), isTrue);
      expect(
          evaluator.evaluateCondition('score < 20', context), isFalse);
    });

    test('greater than or equal comparison', () {
      final context = ProfileContext(variables: {'score': 70});
      expect(
          evaluator.evaluateCondition('score >= 70', context), isTrue);
      expect(
          evaluator.evaluateCondition('score >= 71', context), isFalse);
    });

    test('less than or equal comparison', () {
      final context = ProfileContext(variables: {'score': 50});
      expect(
          evaluator.evaluateCondition('score <= 50', context), isTrue);
      expect(
          evaluator.evaluateCondition('score <= 49', context), isFalse);
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — extractVariables
  // ===========================================================================

  group('ExpressionEvaluator extractVariables', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('finds mustache variables', () {
      final vars =
          evaluator.extractVariables('Hello {{name}}, you have {{count}} items');

      expect(vars, contains('name'));
      expect(vars, contains('count'));
    });

    test('finds dart interpolation variables with braces', () {
      final vars = evaluator.extractVariables(r'Hello ${name}, ${count} items');

      expect(vars, contains('name'));
      expect(vars, contains('count'));
    });

    test('finds simple dart interpolation variables', () {
      final vars = evaluator.extractVariables(r'Hello $name');

      expect(vars, contains('name'));
    });

    test('returns empty set for plain text', () {
      final vars = evaluator.extractVariables('No variables here');

      expect(vars, isEmpty);
    });

    test('strips filters from mustache variable names', () {
      final vars = evaluator.extractVariables('{{name | upper}}');

      expect(vars, contains('name'));
      expect(vars.length, equals(1));
    });

    test('deduplicates repeated variables', () {
      final vars =
          evaluator.extractVariables('{{name}} and {{name}} again');

      expect(vars.length, equals(1));
      expect(vars, contains('name'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — validate
  // ===========================================================================

  group('ExpressionEvaluator validate', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('valid template returns no errors', () {
      final errors = evaluator.validate('Hello {{name}}, welcome!');

      expect(errors, isEmpty);
    });

    test('unbalanced mustache braces returns error', () {
      final errors = evaluator.validate('Hello {{name, welcome!');

      expect(errors, isNotEmpty);
      expect(errors.first.type,
          equals(ExpressionErrorType.unclosedExpression));
    });

    test('properly closed template returns no errors', () {
      final errors = evaluator.validate('{{a}} and {{b}}');

      expect(errors, isEmpty);
    });

    test('plain text returns no errors', () {
      final errors = evaluator.validate('Just plain text');

      expect(errors, isEmpty);
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — registerFunction
  // ===========================================================================

  group('ExpressionEvaluator registerFunction', () {
    test('custom function can be called from template', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);

      evaluator.registerFunction('double', (args, context) {
        if (args.isEmpty) return 0;
        final val = args[0];
        if (val is num) return val * 2;
        return val;
      });

      final context = ProfileContext(variables: {'x': 5});
      final result = evaluator.evaluate('{{double(x)}}', context);

      expect(result, equals('10'));
    });

    test('custom function with no args', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);

      evaluator.registerFunction('greeting', (args, context) {
        return 'Hello World';
      });

      final context = ProfileContext();
      final result = evaluator.evaluate('{{greeting()}}', context);

      expect(result, equals('Hello World'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — registerFilter
  // ===========================================================================

  group('ExpressionEvaluator registerFilter', () {
    test('custom filter applicable in template', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);

      evaluator.registerFilter('reverse', (value, args) {
        return value.toString().split('').reversed.join('');
      });

      final context = ProfileContext(variables: {'word': 'hello'});
      final result = evaluator.evaluate('{{word | reverse}}', context);

      expect(result, equals('olleh'));
    });

    test('custom filter overrides built-in filter', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);

      // Override the built-in upper filter
      evaluator.registerFilter('upper', (value, args) {
        return 'CUSTOM-${value.toString().toUpperCase()}';
      });

      final context = ProfileContext(variables: {'name': 'test'});
      final result = evaluator.evaluate('{{name | upper}}', context);

      expect(result, equals('CUSTOM-TEST'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — dot notation in context
  // ===========================================================================

  group('ExpressionEvaluator dot notation context access', () {
    test('resolves user.name via dot notation', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(user: {'name': 'Alice'});

      final result = evaluator.evaluate('{{user.name}}', context);

      expect(result, equals('Alice'));
    });

    test('resolves environment variables via env prefix', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(environment: {'mode': 'production'});

      final result = evaluator.evaluate('{{env.mode}}', context);

      expect(result, equals('production'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — evaluateCondition (additional coverage)
  // ===========================================================================

  group('ExpressionEvaluator evaluateCondition (additional)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('negation with leading/trailing spaces around variable', () {
      final context = ProfileContext(variables: {'active': true});
      // "! active" with space after !
      expect(evaluator.evaluateCondition('! active', context), isFalse);
    });

    test('negation of falsy variable returns true', () {
      final context = ProfileContext(variables: {'zero': 0});
      expect(evaluator.evaluateCondition('!zero', context), isTrue);
    });

    test('>= operator with left greater than right', () {
      final context = ProfileContext(variables: {'val': 100});
      expect(evaluator.evaluateCondition('val >= 50', context), isTrue);
    });

    test('<= operator with left less than right', () {
      final context = ProfileContext(variables: {'val': 10});
      expect(evaluator.evaluateCondition('val <= 50', context), isTrue);
    });

    test('>= operator returns false when less', () {
      final context = ProfileContext(variables: {'val': 5});
      expect(evaluator.evaluateCondition('val >= 10', context), isFalse);
    });

    test('<= operator returns false when greater', () {
      final context = ProfileContext(variables: {'val': 20});
      expect(evaluator.evaluateCondition('val <= 10', context), isFalse);
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — extractVariables (additional coverage)
  // ===========================================================================

  group('ExpressionEvaluator extractVariables (additional)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('finds simple \$variable (no braces) dart syntax', () {
      final vars = evaluator.extractVariables(r'Hello $userName and $age');
      expect(vars, contains('userName'));
      expect(vars, contains('age'));
    });

    test('finds mixed mustache, braced dart, and simple dart variables', () {
      final vars = evaluator
          .extractVariables(r'{{title}} by $author (${year})');
      expect(vars, contains('title'));
      expect(vars, contains('author'));
      expect(vars, contains('year'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — validate (additional coverage)
  // ===========================================================================

  group('ExpressionEvaluator validate (additional)', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('unbalanced dart interpolation braces returns error', () {
      // Has ${ without a matching }
      final errors = evaluator.validate(r'Hello ${name, welcome!');
      expect(errors, isNotEmpty);
      expect(errors.any(
        (e) => e.type == ExpressionErrorType.unclosedExpression &&
            e.message.contains('dart interpolation'),
      ), isTrue);
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — _stringify (additional coverage)
  // ===========================================================================

  group('ExpressionEvaluator _stringify via evaluate', () {
    test('null variable renders as empty string', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      // Evaluating a null-resolving variable (via 'null' literal)
      final context = ProfileContext(variables: {});
      // 'null' literal resolves to null in _resolveValue
      final result = evaluator.evaluate('{{null}}', context);
      expect(result, equals(''));
    });

    test('numeric variable renders via toString', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(variables: {'num': 42});
      final result = evaluator.evaluate('{{num}}', context);
      expect(result, equals('42'));
    });

    test('boolean variable renders via toString', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(variables: {'flag': true});
      final result = evaluator.evaluate('{{flag}}', context);
      expect(result, equals('true'));
    });

    test('list variable renders via toString', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(variables: {
        'items': [1, 2, 3],
      });
      final result = evaluator.evaluate('{{items}}', context);
      expect(result, equals('[1, 2, 3]'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — unknown function (line 234)
  // ===========================================================================

  group('ExpressionEvaluator unknown function', () {
    test('calling unknown function returns placeholder string', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(variables: {});

      final result = evaluator.evaluate('{{unknownFn()}}', context);

      expect(result, contains('unknown function'));
      expect(result, contains('unknownFn'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — _isTruthy for String, List, Map (lines 283-285)
  // ===========================================================================

  group('ExpressionEvaluator evaluateCondition _isTruthy coverage', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    test('non-empty string is truthy', () {
      final context = ProfileContext(variables: {'name': 'hello'});
      expect(evaluator.evaluateCondition('name', context), isTrue);
    });

    test('empty string is falsy', () {
      final context = ProfileContext(variables: {'name': ''});
      expect(evaluator.evaluateCondition('name', context), isFalse);
    });

    test('non-empty list is truthy', () {
      final context = ProfileContext(variables: {
        'items': [1, 2],
      });
      expect(evaluator.evaluateCondition('items', context), isTrue);
    });

    test('empty list is falsy', () {
      final context = ProfileContext(variables: {'items': <int>[]});
      expect(evaluator.evaluateCondition('items', context), isFalse);
    });

    test('non-empty map is truthy', () {
      final context = ProfileContext(variables: {
        'data': {'key': 'value'},
      });
      expect(evaluator.evaluateCondition('data', context), isTrue);
    });

    test('empty map is falsy', () {
      final context =
          ProfileContext(variables: {'data': <String, dynamic>{}});
      expect(evaluator.evaluateCondition('data', context), isFalse);
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — len() with List and Map (lines 301-302)
  // ===========================================================================

  group('ExpressionEvaluator len() function for List and Map', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('len function returns list length', () {
      final context = ProfileContext(variables: {
        'items': [10, 20, 30],
      });

      final result = evaluator.evaluate('{{len(items)}}', context);

      expect(result, equals('3'));
    });

    test('len function returns map length', () {
      final context = ProfileContext(variables: {
        'data': {'a': 1, 'b': 2},
      });

      final result = evaluator.evaluate('{{len(data)}}', context);

      expect(result, equals('2'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — join() on non-list (line 325)
  // ===========================================================================

  group('ExpressionEvaluator join() function on non-list', () {
    test('join on non-list value returns toString', () {
      final evaluator =
          ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
      final context = ProfileContext(variables: {'scalar': 'hello'});

      final result = evaluator.evaluate('{{join(scalar)}}', context);

      expect(result, equals('hello'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — default filter (lines 342-343)
  // ===========================================================================

  group('ExpressionEvaluator default filter', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('default filter returns fallback when value is null', () {
      final context = ProfileContext(variables: {});

      final result =
          evaluator.evaluate('{{missing | default: fallback}}', context);

      expect(result, equals('fallback'));
    });

    test('default filter returns fallback when value is empty string', () {
      final context = ProfileContext(variables: {'name': ''});

      final result =
          evaluator.evaluate('{{name | default: anonymous}}', context);

      expect(result, equals('anonymous'));
    });

    test('default filter returns original when value is present', () {
      final context = ProfileContext(variables: {'name': 'Alice'});

      final result =
          evaluator.evaluate('{{name | default: anonymous}}', context);

      expect(result, equals('Alice'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — truncate filter (lines 350-353)
  // ===========================================================================

  group('ExpressionEvaluator truncate filter', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('truncate filter truncates long string with ellipsis', () {
      final context = ProfileContext(
        variables: {'text': 'This is a very long string that should be truncated'},
      );

      final result =
          evaluator.evaluate('{{text | truncate: 10}}', context);

      expect(result, equals('This is a ...'));
    });

    test('truncate filter returns short string unchanged', () {
      final context = ProfileContext(variables: {'text': 'Short'});

      final result =
          evaluator.evaluate('{{text | truncate: 10}}', context);

      expect(result, equals('Short'));
    });

    test('truncate filter uses default length of 50 when no arg', () {
      final context = ProfileContext(
        variables: {'text': 'A' * 60},
      );

      final result =
          evaluator.evaluate('{{text | truncate}}', context);

      expect(result.length, equals(53)); // 50 chars + "..."
      expect(result, endsWith('...'));
    });
  });

  // ===========================================================================
  // ExpressionEvaluator — json filter (lines 358, 360, 362)
  // ===========================================================================

  group('ExpressionEvaluator json filter', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator(syntax: ExpressionSyntax.mustache);
    });

    test('json filter on map returns map toString', () {
      final context = ProfileContext(variables: {
        'data': {'key': 'value'},
      });

      final result = evaluator.evaluate('{{data | json}}', context);

      expect(result, contains('key'));
      expect(result, contains('value'));
    });

    test('json filter on list returns list toString', () {
      final context = ProfileContext(variables: {
        'items': [1, 2, 3],
      });

      final result = evaluator.evaluate('{{items | json}}', context);

      expect(result, contains('1'));
      expect(result, contains('2'));
      expect(result, contains('3'));
    });

    test('json filter on scalar wraps in quotes', () {
      final context = ProfileContext(variables: {'name': 'Alice'});

      final result = evaluator.evaluate('{{name | json}}', context);

      expect(result, equals('"Alice"'));
    });
  });
}
