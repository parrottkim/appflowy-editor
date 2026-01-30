import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/plugins/markdown/decoder/custom_syntaxes/underline_syntax.dart';
import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart' as md;

import 'custom_syntaxes/formula_syntax.dart';

class DocumentMarkdownDecoder extends Converter<String, Document> {
  DocumentMarkdownDecoder({
    this.markdownElementParsers = const [],
    this.inlineSyntaxes = const [],
  });

  final List<CustomMarkdownParser> markdownElementParsers;
  final List<md.InlineSyntax> inlineSyntaxes;

  @override
  Document convert(String input) {
    final formattedMarkdown = _formatMarkdown(input);
    final List<md.Node> mdNodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [
        ...inlineSyntaxes,
        FormulaInlineSyntax(),
        UnderlineInlineSyntax(),
      ],
      encodeHtml: false,
    ).parse(formattedMarkdown);

    final document = Document.blank();
    final nodes = mdNodes
        .map((e) => _parseNode(e))
        .nonNulls
        .flattened
        .toList(growable: false); // avoid lazy evaluation
    
    // If the document ends with an image, add an empty paragraph for cursor positioning
    if (nodes.isNotEmpty && 
        nodes.last.type == ImageBlockKeys.type &&
        (nodes.last.next == null)) {
      nodes.add(paragraphNode());
    }
    
    if (nodes.isNotEmpty) {
      document.insert([0], nodes);
    }

    return document;
  }

  // handle node itself and its children
  List<Node> _parseNode(md.Node mdNode) {
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
    // 1. Isolate every image by adding double newlines before and after it.
    // This ensures that images are separated from surrounding text and other images,
    // which is essential for the parser to treat each image as a standalone block.
    String result = markdown.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (match) => '\n\n${match.group(0)}\n\n',
    );

    // 2. Normalize excessive newlines (3 or more) into a single blank line (\n\n).
    // This cleans up any redundant spacing created by the isolation step
    // while maintaining valid Markdown block structures.
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Trim leading whitespace and normalize trailing whitespace
    result = result.trimLeft();
    // Only trim trailing spaces/tabs, preserve newlines for proper markdown parsing
    result = result.replaceAll(RegExp(r'[ \t]+$'), '');
    
    return result;
  }
}
