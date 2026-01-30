import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  group('image_node_parser.dart', () {
    test('parser image node', () {
      final node = Node(
        type: 'image',
        attributes: {
          'url': 'https://appflowy.io',
        },
      );

      final result = const ImageNodeParser().transform(node, null);
      expect(result, '![](https://appflowy.io)\n');
    });

    test('ImageNodeParser id getter', () {
      const imageNodeParser = ImageNodeParser();
      expect(imageNodeParser.id, 'image');
    });

    test('parser image node with next node (no trailing newline)', () {
      final pageNode = Node(type: 'page', children: [
        Node(
          type: 'image',
          attributes: {
            'url': 'https://appflowy.io/image.png',
          },
        ),
        Node(type: 'paragraph'),
      ]);

      final imageNode = pageNode.children[0];
      final result = const ImageNodeParser().transform(imageNode, null);
      // When there's a next node, trailing newline should be added
      expect(result, '![](https://appflowy.io/image.png)\n');
    });
  });
}
