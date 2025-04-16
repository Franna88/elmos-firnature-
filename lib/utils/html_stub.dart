// This is a stub implementation of the html library for non-web platforms
// It provides the necessary classes and methods to prevent compile errors

class AnchorElement {
  AnchorElement({String? href}) : _href = href;

  final String? _href;
  final ElementStyle style = ElementStyle();

  void setAttribute(String name, String value) {}

  void click() {}
}

class ElementStyle {
  String display = '';
}

class Document {
  final DocumentBody? body = DocumentBody();
}

class DocumentBody {
  final List<dynamic> children = [];

  void add(dynamic element) {}

  void remove(dynamic element) {}
}

final Document document = Document();
