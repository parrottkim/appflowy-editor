import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/plugins/markdown/decoder/custom_syntaxes/underline_syntax.dart';
import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart' as md;

import 'custom_syntaxes/formula_syntax.dart';

const _emptyParagraphMarker = '\u{E000}appflowy-empty-paragraph\u{E001}';

class DocumentMarkdownDecoder extends Converter<String, Document> {
  DocumentMarkdownDecoder({
    this.markdownElementParsers = const [],
    this.inlineSyntaxes = const [],
  });

  final List<CustomMarkdownParser> markdownElementParsers;
  final List<md.InlineSyntax> inlineSyntaxes;

  @override
  Document convert(String input) {
    final markdown = _formatMarkdown(_replaceEmptyLinesWithParagraphs(input));
    final List<md.Node> mdNodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [
        ...inlineSyntaxes,
        FormulaInlineSyntax(),
        UnderlineInlineSyntax(),
      ],
      encodeHtml: false,
    ).parse(markdown);

    final document = Document.blank();
    final nodes = mdNodes
        .map((e) => _parseNode(e))
        .nonNulls
        .flattened
        .toList(growable: false); // avoid lazy evaluation
    if (nodes.isNotEmpty) {
      document.insert([0], nodes);
    }

    if (document.last?.type == ImageBlockKeys.type) {
      final trailingParagraph = paragraphNode()
        ..extraInfos = {'markdownTrailingImageParagraph': true};
      document.insert([document.root.children.length], [trailingParagraph]);
    }

    return document;
  }

  // handle node itself and its children
  List<Node> _parseNode(md.Node mdNode) {
    if (mdNode.textContent == _emptyParagraphMarker) {
      return [paragraphNode()];
    }

    List<Node> nodes = [];

    for (final parser in markdownElementParsers) {
      nodes = parser.transform(
        mdNode,
        markdownElementParsers,
      );

      if (nodes.isNotEmpty) {
        break;
      }
    }

    if (nodes.isEmpty) {
      AppFlowyEditorLog.editor.debug(
        'empty result from node: $mdNode, text: ${mdNode.textContent}',
      );
    }

    return nodes;
  }

  String _formatMarkdown(String markdown) {
    // Rule 1: single '\n' between text and image, add double '\n'
    String result = markdown.replaceAllMapped(
      RegExp(r'([^\n])\n!\[([^\]]*)\]\(([^)]+)\)', multiLine: true),
      (match) {
        final text = match[1] ?? '';
        final altText = match[2] ?? '';
        final url = match[3] ?? '';

        return '$text\n\n![$altText]($url)';
      },
    );

    // Rule 2: without '\n' between text and image, add double '\n'
    result = result.replaceAllMapped(
      RegExp(r'([^\n])!\[([^\]]*)\]\(([^)]+)\)'),
      (match) => '${match[1]}\n\n![${match[2]}](${match[3]})',
    );

    // Rule 3: single '\n' between image and text, add double '\n'
    result = result.replaceAllMapped(
      RegExp(r'(!\[[^\]]*\]\([^)]+\))\n([^\n])'),
      (match) => '${match[1]}\n\n${match[2]}',
    );

    return result;
  }

  String _replaceEmptyLinesWithParagraphs(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final firstContentIndex =
        lines.indexWhere((line) => line.trim().isNotEmpty);
    final lastContentIndex = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty,
    );
    String? fenceCharacter;
    var fenceLength = 0;

    for (var index = 0; index < lines.length; index++) {
      final trimmed = lines[index].trimLeft();
      final fenceMatch = RegExp('^(`{3,}|~{3,})').firstMatch(trimmed);

      if (fenceMatch != null) {
        final fence = fenceMatch.group(1)!;

        if (fenceCharacter == null) {
          fenceCharacter = fence[0];
          fenceLength = fence.length;
        } else if (fence[0] == fenceCharacter && fence.length >= fenceLength) {
          fenceCharacter = null;
          fenceLength = 0;
        }
        continue;
      }

      if (fenceCharacter != null || lines[index].trim().isNotEmpty) {
        continue;
      }

      if (index <= firstContentIndex || index >= lastContentIndex) {
        continue;
      }

      final previousContentIndex = lines.lastIndexWhere(
        (line) => line.trim().isNotEmpty,
        index - 1,
      );
      final nextContentIndex = lines.indexWhere(
        (line) => line.trim().isNotEmpty,
        index + 1,
      );

      if (previousContentIndex >= 0 &&
          nextContentIndex >= 0 &&
          _isIndentedCodeLine(lines[previousContentIndex]) &&
          _isIndentedCodeLine(lines[nextContentIndex])) {
        continue;
      }

      lines[index] = '\n$_emptyParagraphMarker\n';
    }

    return lines.join('\n');
  }

  bool _isIndentedCodeLine(String line) {
    return line.startsWith('    ') || line.startsWith('\t');
  }
}
