import 'package:appflowy_editor/appflowy_editor.dart';

class ImageNodeParser extends NodeParser {
  const ImageNodeParser();

  @override
  String get id => ImageBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final nextNode = node.next;
    final isTrailingImageParagraph =
        nextNode?.extraInfos?['markdownTrailingImageParagraph'] == true;
    final suffix = nextNode == null || isTrailingImageParagraph ? '' : '\n';
    return '![](${node.attributes[ImageBlockKeys.url]})$suffix';
  }
}
