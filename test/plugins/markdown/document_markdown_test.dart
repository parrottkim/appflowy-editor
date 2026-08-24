import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  group('document_markdown.dart tests', () {
    test('markdownToDocument()', () {
      final document = markdownToDocument(markdownDocument);
      final data = Map<String, Object>.from(json.decode(testDocument));

      expect(document.toJson(), data);
    });

    test('soft line break with two spaces', () {
      const markdown = 'first line  \nsecond line';
      final document = markdownToDocument(markdown);
      expect(document.root.children.length, 2);
      expect(document.root.children[0].delta?.toPlainText(), 'first line');
      expect(document.root.children[1].delta?.toPlainText(), 'second line');
    });

    test('preserves empty paragraphs', () {
      const markdown = 'first\n\n# heading\n\nlast';
      final document = markdownToDocument(markdown);
      final nodes = document.root.children;

      expect(nodes.length, 5);
      expect(nodes[0].delta?.toPlainText(), 'first');
      expect(nodes[1].type, ParagraphBlockKeys.type);
      expect(nodes[1].delta?.isEmpty, isTrue);
      expect(nodes[2].type, HeadingBlockKeys.type);
      expect(nodes[3].type, ParagraphBlockKeys.type);
      expect(nodes[3].delta?.isEmpty, isTrue);
      expect(nodes[4].delta?.toPlainText(), 'last');
    });

    test('preserved empty paragraphs are stable after a markdown round trip',
        () {
      const markdown = 'first\n\n# heading\n\nlast';
      final document = markdownToDocument(markdown);
      final encoded = documentToMarkdown(document);
      final restored = markdownToDocument(encoded);

      expect(encoded, '$markdown\n');
      expect(restored.toJson(), document.toJson());
    });

    test('preserves consecutive empty paragraphs', () {
      const markdown = 'first\n\n\nlast';
      final document = markdownToDocument(markdown);
      final encoded = documentToMarkdown(document);
      final restored = markdownToDocument(encoded);

      expect(document.root.children, hasLength(4));
      expect(document.root.children[1].delta?.isEmpty, isTrue);
      expect(document.root.children[2].delta?.isEmpty, isTrue);
      expect(encoded, '$markdown\n');
      expect(restored.toJson(), document.toJson());
    });

    test('preserves empty paragraphs around headings and lists', () {
      const markdown = '''asdfasdf

# 안녕하세요

## 안녕하십니까 백과사전

음료수

- 일번
- 이번
- 삼번

테스트''';
      final document = markdownToDocument(markdown);
      final encoded = documentToMarkdown(document);
      final restored = markdownToDocument(encoded);

      expect(document.root.children, hasLength(13));
      expect(
        document.root.children
            .where(
              (node) =>
                  node.type == ParagraphBlockKeys.type &&
                  (node.delta?.isEmpty ?? false),
            )
            .length,
        5,
      );
      expect(
        encoded,
        '${markdown.replaceAll(RegExp('^- ', multiLine: true), '* ')}\n',
      );
      expect(restored.toJson(), document.toJson());
    });

    test('does not preserve empty lines inside fenced code blocks', () {
      const markdown = '```\nfirst\n\nlast\n```';
      final document = markdownToDocument(
        markdown,
        markdownParsers: const [_FencedCodeParser()],
      );

      expect(document.root.children, hasLength(1));
      expect(
        document.root.children.single.delta?.toPlainText(),
        'first\n\nlast',
      );
    });

    test('does not preserve empty lines inside indented code blocks', () {
      const markdown = '    first\n\n    last';
      final document = markdownToDocument(
        markdown,
        markdownParsers: const [_FencedCodeParser()],
      );

      expect(document.root.children, hasLength(1));
      expect(
        document.root.children.single.delta?.toPlainText(),
        'first\n\nlast',
      );
    });

    test('documentToMarkdown()', () {
      final document = markdownToDocument(markdownDocument);
      final markdown = documentToMarkdown(document);

      expect(markdown, markdownDocumentEncoded);
    });

    test('paragraph + image with single \n', () {
      const markdown = '''This is the first line
![image](https://example.com/image.png)''';
      final document = markdownToDocument(markdown);
      final nodes = document.root.children;
      expect(nodes.length, 3);
      expect(nodes[0].delta?.toPlainText(), 'This is the first line');
      expect(nodes[1].attributes['url'], 'https://example.com/image.png');
      expect(nodes[2].delta?.isEmpty, isTrue);
    });

    test('paragraph + image with double \n', () {
      const markdown = '''This is the first line

![image](https://example.com/image.png)''';
      final document = markdownToDocument(markdown);
      final nodes = document.root.children;
      expect(nodes.length, 4);
      expect(nodes[0].delta?.toPlainText(), 'This is the first line');
      expect(nodes[1].type, ParagraphBlockKeys.type);
      expect(nodes[1].delta?.isEmpty, isTrue);
      expect(nodes[2].attributes['url'], 'https://example.com/image.png');
      expect(nodes[3].delta?.isEmpty, isTrue);
    });

    test('paragraph + image without \n', () {
      const markdown =
          '''This is the first line![image](https://example.com/image.png)''';
      final document = markdownToDocument(markdown);
      final nodes = document.root.children;
      expect(nodes.length, 3);
      expect(nodes[0].delta?.toPlainText(), 'This is the first line');
      expect(nodes[1].attributes['url'], 'https://example.com/image.png');
      expect(nodes[2].delta?.isEmpty, isTrue);
    });

    test('adds a trailing paragraph when markdown ends with an image', () {
      const markdown = '![](https://example.com/image.png)';
      final document = markdownToDocument(markdown);
      final nodes = document.root.children;

      expect(nodes, hasLength(2));
      expect(nodes.first.type, ImageBlockKeys.type);
      expect(nodes.last.type, ParagraphBlockKeys.type);
      expect(nodes.last.delta?.isEmpty, isTrue);
    });

    // Regression test for https://github.com/AppFlowy-IO/AppFlowy/issues/8486
    // documentToMarkdown() must not mutate the source document when processing
    // nested (indented) list items.
    test('documentToMarkdown does not orphan children of nested list items',
        () {
      final childNode = bulletedListNode(text: 'Child item');
      final parentNode = bulletedListNode(
        text: 'Parent item',
        children: [childNode],
      );
      final document = Document(root: pageNode(children: [parentNode]));

      // Verify initial structure: parent has 1 child.
      expect(document.root.children.length, 1);
      expect(document.root.children.first.children.length, 1);

      final markdown = documentToMarkdown(document);

      // The markdown output should be correct.
      expect(markdown, '* Parent item\n\t* Child item\n');

      // After conversion, the source document must be unchanged.
      // Before the fix, convertNodes() called pageNode(children: nodes) which
      // invoked unlink() on each child, removing them from their original parent.
      expect(
        document.root.children.first.children.length,
        1,
        reason:
            'documentToMarkdown() must not remove children from the source document',
      );
    });
  });
}

class _FencedCodeParser extends CustomMarkdownParser {
  const _FencedCodeParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element || element.tag != 'pre') {
      return [];
    }

    return [paragraphNode(text: element.textContent.trimRight())];
  }
}

const testDocument = '''{
  "document": {
    "type": "page",
    "children": [
      {
        "type": "heading",
        "data": {"level": 1, "delta": [{"insert": "Heading 1"}]}
      },
      {
        "type": "heading",
        "data": {"level": 2, "delta": [{"insert": "Heading 2"}]}
      },
      {
        "type": "heading",
        "data": {"level": 3, "delta": [{"insert": "Heading 3"}]}
      },
      {"type": "divider"}
    ]
  }
}''';

const markdownDocument = """
# Heading 1
## Heading 2
### Heading 3
---""";

const markdownDocumentEncoded = """
# Heading 1
## Heading 2
### Heading 3
---
""";
