// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:parchment/parchment.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';

final ul = ParchmentAttribute.ul.toJson();
final bold = ParchmentAttribute.bold.toJson();

void main() {
  group('$CatchAllInsertRule', () {
    final rule = CatchAllInsertRule();

    test('applies change as-is', () {
      final doc = Delta()..insert('Document\n');
      final actual = rule.apply(doc, 8, '!');
      final expected = Delta()
        ..retain(8)
        ..insert('!');
      expect(actual, expected);
    });
  });

  group('$PreserveLineStyleOnSplitRule', () {
    final rule = PreserveLineStyleOnSplitRule();

    test('skips at the beginning of a document', () {
      final doc = Delta()..insert('One\n');
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNull);
    });

    test('applies in a block', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 8, '\n');
      final expected = Delta()
        ..retain(8)
        ..insert('\n', ul);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('applies before an embed', () {
      final doc = Delta()
        ..insert('Hello ')
        ..insert({'_type': 'icon', '_inline': true})
        ..insert('\n');
      final actual = rule.apply(doc, 6, '\n');
      final expected = Delta()
        ..retain(6)
        ..insert('\n');
      expect(actual, isNotNull);
      expect(actual, expected);
    });
  });

  group('$ResetLineFormatOnNewLineRule', () {
    final rule = const ResetLineFormatOnNewLineRule();

    test('applies when line-break is inserted at the end of line', () {
      final doc = Delta()
        ..insert('Hello world')
        ..insert('\n', ParchmentAttribute.h1.toJson());
      final actual = rule.apply(doc, 11, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(11)
        ..insert('\n', ParchmentAttribute.h1.toJson())
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });

    test("doesn't apply without style reset if not needed", () {
      final doc = Delta()..insert('Hello world\n');
      final actual = rule.apply(doc, 11, '\n');
      expect(actual, isNull);
    });

    test('applies at the beginning of a document', () {
      final doc = Delta()..insert('\n', ParchmentAttribute.h1.toJson());
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..insert('\n', ParchmentAttribute.h1.toJson())
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });

    test('applies and keeps block style', () {
      final style = ParchmentAttribute.ul.toJson();
      style.addAll(ParchmentAttribute.h1.toJson());
      final doc = Delta()
        ..insert('Hello world')
        ..insert('\n', style);
      final actual = rule.apply(doc, 11, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(11)
        ..insert('\n', style)
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });

    test('applies to a line in the middle of a document', () {
      final doc = Delta()
        ..insert('Hello \nworld!\nMore lines here.')
        ..insert('\n', ParchmentAttribute.h2.toJson());
      final actual = rule.apply(doc, 30, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(30)
        ..insert('\n', ParchmentAttribute.h2.toJson())
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });
  });

  group('$AutoExitBlockRule', () {
    final rule = AutoExitBlockRule();

    test('applies when newline is inserted on the last empty line in a block',
        () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Item 1')
        ..insert('\n', ul)
        ..insert('Item 2')
        ..insert('\n\n', ul);
      final actual = rule.apply(doc, 14, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(14)
        ..retain(1, ParchmentAttribute.block.unset.toJson());
      expect(actual, expected);
    });

    test('applies only on empty line', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Item 1')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 6, '\n');
      expect(actual, isNull);
    });

    test('applies at the beginning of a document', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()..insert('\n', ul);
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(1, ParchmentAttribute.block.unset.toJson());
      expect(actual, expected);
    });

    test('ignores non-empty line at the beginning of a document', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Text')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNull);
    });

    test('ignores empty lines in the middle of a block', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Line1')
        ..insert('\n\n\n\n', ul);
      final actual = rule.apply(doc, 7, '\n');
      expect(actual, isNull);
    });
  });

  group('$PreserveInlineStylesRule', () {
    final rule = PreserveInlineStylesRule();
    test('apply', () {
      final doc = Delta()
        ..insert('Doc with ')
        ..insert('bold', bold)
        ..insert(' text');
      final actual = rule.apply(doc, 13, 'er');
      final expected = Delta()
        ..retain(13)
        ..insert('er', bold);
      expect(expected, actual);
    });

    test('apply at the beginning of a document', () {
      final doc = Delta()..insert('Doc with ');
      final actual = rule.apply(doc, 0, 'A ');
      expect(actual, isNull);
    });
  });

  group('$AutoFormatLinksRule', () {
    final rule = AutoFormatLinksRule();
    final link =
        ParchmentAttribute.link.fromString('https://example.com').toJson();

    test('apply simple', () {
      final doc = Delta()..insert('Doc with link https://example.com');
      final actual = rule.apply(doc, 33, ' ');
      final expected = Delta()
        ..retain(14)
        ..retain(19, link)
        ..insert(' ');
      expect(expected, actual);
    });

    test('apply simple newline', () {
      final doc = Delta()..insert('Doc with link https://example.com');
      final actual = rule.apply(doc, 33, '\n');
      final expected = Delta()
        ..retain(14)
        ..retain(19, link)
        ..insert('\n');
      expect(expected, actual);
    });

    test('applies only to insert of single space', () {
      final doc = Delta()..insert('Doc with link https://example.com');
      final actual = rule.apply(doc, 33, '/');
      expect(actual, isNull);
    });

    test('applies for links at the beginning of line', () {
      final doc = Delta()..insert('Doc with link\nhttps://example.com');
      final actual = rule.apply(doc, 33, ' ');
      final expected = Delta()
        ..retain(14)
        ..retain(19, link)
        ..insert(' ');
      expect(expected, actual);
    });

    test('ignores if already formatted as link', () {
      final doc = Delta()
        ..insert('Doc with link\n')
        ..insert('https://example.com', link);
      final actual = rule.apply(doc, 33, ' ');
      expect(actual, isNull);
    });
  });

  group('$PreserveBlockStyleOnInsertRule', () {
    final rule = PreserveBlockStyleOnInsertRule();

    test('applies in a block', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 8, 'also \n');
      final expected = Delta()
        ..retain(8)
        ..insert('also ')
        ..insert('\n', ul);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('formats a link in a block', () {
      final link = ParchmentAttribute.link.fromString('http://a.com').toJson();
      final doc = Delta()
        ..insert('http://a.com')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 12, '\n');
      final expected = Delta()
        ..retain(12, link)
        ..insert('\n', ul);
      expect(actual, expected);
    });

    test('applies for single newline insert', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 12, '\n');
      final expected = Delta()
        ..retain(12)
        ..insert('\n', ul);
      expect(actual, expected);
    });

    test('applies for multi line insert', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 8, '111\n222\n333');
      final expected = Delta()
        ..retain(8)
        ..insert('111')
        ..insert('\n', ul)
        ..insert('222')
        ..insert('\n', ul)
        ..insert('333');
      expect(actual, expected);
    });

    test('preserves heading style of the original line', () {
      final quote = ParchmentAttribute.block.quote.toJson();
      final h1Unset = ParchmentAttribute.heading.unset.toJson();
      final quoteH1 = ParchmentAttribute.block.quote.toJson();
      quoteH1.addAll(ParchmentAttribute.heading.level1.toJson());
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', quoteH1)
        ..insert('Three')
        ..insert('\n', quote);
      final actual = rule.apply(doc, 8, '111\n');
      final expected = Delta()
        ..retain(8)
        ..insert('111')
        ..insert('\n', quoteH1)
        ..retain(3)
        ..retain(1, h1Unset);
      expect(actual, expected);
    });

    test('preserves checked style of the original line', () {
      final cl = ParchmentAttribute.cl.toJson();
      final checkedUnset = ParchmentAttribute.checked.unset.toJson();
      final clChecked = ParchmentAttribute.cl.toJson();
      clChecked.addAll(ParchmentAttribute.checked.toJson());
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', clChecked)
        ..insert('Three')
        ..insert('\n', cl);
      final actual = rule.apply(doc, 8, '111\n');
      final expected = Delta()
        ..retain(8)
        ..insert('111')
        ..insert('\n', clChecked)
        ..retain(3)
        ..retain(1, checkedUnset);
      expect(actual, expected);
    });
  });

  group('$InsertBlockEmbedsRule', () {
    final rule = InsertBlockEmbedsRule();

    test('insert on an empty line', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n')
        ..insert('\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 12, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(12)
        ..insert(BlockEmbed.horizontalRule);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('insert in the beginning of a line', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 12, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(12)
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('insert in the end of a line', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 11, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(11)
        ..insert('\n')
        ..insert(BlockEmbed.horizontalRule);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('insert in the middle of a line', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 17, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(17)
        ..insert('\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('inserted object is not block embed', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      expect(rule.apply(doc, 17, 'Some text'), isNull);
      expect(rule.apply(doc, 17, SpanEmbed('span')), isNull);
    });
  });

  group('$MarkdownBlockShortcutsInsertRule', () {
    final rule = MarkdownBlockShortcutsInsertRule();

    test('apply markdown shortcut on single-line document', () {
      final doc = Delta()..insert('#\n');
      final actual = rule.apply(doc, 1, ' ');
      final expected = Delta()
        ..delete(1)
        ..retain(1, ParchmentAttribute.h1.toJson());
      expect(actual, expected);
    });

    test('ignores if already formatted with the same style', () {
      final doc = Delta()
        ..insert('#')
        ..insert('\n', ParchmentAttribute.h1.toJson());
      final actual = rule.apply(doc, 1, ' ');
      expect(actual, isNull);
    });

    test('changes existing style', () {
      final doc = Delta()
        ..insert('##')
        ..insert('\n', ParchmentAttribute.h1.toJson());
      final actual = rule.apply(doc, 2, ' ');
      final expected = Delta()
        ..delete(2)
        ..retain(1, ParchmentAttribute.h2.toJson());
      expect(actual, expected);
    });

    test('code block format does not require a space after the shortcut', () {
      final doc = Delta()..insert('``\n');
      final actual = rule.apply(doc, 2, '`');
      final expected = Delta()
        ..delete(2)
        ..retain(1, ParchmentAttribute.code.toJson());
      expect(actual, expected);
    });

    test('first space does not break insertion', () {
      final doc = Delta()..insert('``\n');
      final actual = rule.apply(doc, 0, ' ');
      expect(actual, isNull);
    });

    test('applies to lines in the middle of an operation', () {
      final doc = Delta()..insert('line\n###\nzefy\n');
      final changes = rule.apply(doc, 8, ' ');
      final actual = doc.compose(changes!)..trim();
      final expected = Delta()
        ..insert('line\n')
        ..insert('\n', ParchmentAttribute.h3.toJson())
        ..insert('zefy\n');

      expect(actual, expected);
    });

    test('detect previous line correctly', () {
      final doc = Delta()
        ..insert('line\nzefy\n')
        ..insert('###\n');
      final changes = rule.apply(doc, 13, ' ');
      final actual = doc.compose(changes!)..trim();
      final expected = Delta()
        ..insert('line\n')
        ..insert('zefy\n')
        ..insert('\n', ParchmentAttribute.h3.toJson());

      expect(actual, expected);
    });

    test('preserve line attributes', () {
      final doc = Delta()
        ..insert('-item')
        ..insert('\n', ParchmentAttribute.h1.toJson());
      final changes = rule.apply(doc, 1, ' ');
      final actual = doc.compose(changes!)..trim();
      final expected = Delta()
        ..insert('item')
        ..insert(
            '\n',
            ParchmentAttribute.h1.toJson()
              ..addAll(ParchmentAttribute.block.bulletList.toJson()));
      expect(actual, expected);
    });

    test('ignores if already formatted', () {
      final doc = Delta()
        ..insert('- item')
        ..insert('\n', ParchmentAttribute.block.bulletList.toJson());
      final actual = rule.apply(doc, 1, ' ');
      expect(actual, isNull);
    });
  });

  group('$AutoTextDirectionRule', () {
    final rule = AutoTextDirectionRule();

    test('ignores if insert is not in an empty line', () {
      var doc = Delta()..insert('abc\n');
      expect(rule.apply(doc, 3, 'd'), null);
      expect(rule.apply(doc, 0, 'd'), null);
    });

    test('inserted text is rtl', () {
      var doc = Delta()..insert('abc\n\n');
      final actual = rule.apply(doc, 4, 'ب');
      final expected = Delta()
        ..retain(4)
        ..insert('ب')
        ..retain(1, {
          ...ParchmentAttribute.alignment.right.toJson(),
          ...ParchmentAttribute.direction.rtl.toJson(),
        });
      expect(actual, expected);
    });

    test('inserted text is ltr', () {
      var doc = Delta()..insert('abc\n\n');
      final actual = rule.apply(doc, 4, 'd');
      final expected = Delta()
        ..retain(4)
        ..insert('d')
        ..retain(1, {
          ...ParchmentAttribute.alignment.unset.toJson(),
          ...ParchmentAttribute.direction.unset.toJson(),
        });
      expect(actual, expected);
    });
  });
}
