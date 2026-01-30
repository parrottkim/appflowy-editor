import 'package:appflowy_editor/appflowy_editor.dart';

class ImageNodeParser extends NodeParser {
  const ImageNodeParser();

  @override
  String get id => ImageBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final imageMarkdown = '![](${node.attributes[ImageBlockKeys.url]})';
    final suffix = node.next == null ? '' : '\n';
    return '$imageMarkdown$suffix';
  }
}
