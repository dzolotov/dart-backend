import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import 'dart:io';
import 'dart:developer' as developer;
part 'sampleapi.g.dart';

@HiveType(typeId: 0)
class ProductHiveObject {
  @HiveField(0)
  String title;
  @HiveField(1)
  String description;
  @HiveField(2)
  double price;
  @HiveField(3)
  String? photo;

  ProductHiveObject({
    required this.title,
    required this.description,
    required this.price,
    required this.photo,
  });
}

@JsonSerializable()
class ProductDTO {
  int? id;
  String title;
  String description;
  double price;
  String? photo;

  ProductDTO({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    this.photo,
  });

  factory ProductDTO.fromJson(Map<String, dynamic> json) =>
      _$ProductDTOFromJson(json);

  Map<String, dynamic> toJson() => _$ProductDTOToJson(this);

  ProductHiveObject toHive() => ProductHiveObject(
        title: title,
        description: description,
        price: price,
        photo: photo,
      );

  factory ProductDTO.fromHive(int id, ProductHiveObject hive) => ProductDTO(
        id: id,
        title: hive.title,
        description: hive.description,
        price: hive.price,
        photo: hive.photo,
      );

  @override
  String toString() =>
      'Product(id=$id, title=$title, description=$description, price=$price, photo=$photo)';
}

class ProductsHTTPException implements HttpException {
  Uri _uri;
  int _status;
  String _message;

  ProductsHTTPException(this._status, this._uri, this._message);

  int get status => _status;

  @override
  String get message => _message;

  @override
  Uri? get uri => _uri;
}

abstract interface class ProductsRepository {
  Future<void> init();
  Future<void> dispose();
  FutureOr<List<ProductDTO>> getProducts();
  FutureOr<ProductDTO?> getProduct(int id);
  FutureOr<int> addProduct(ProductDTO product);
  FutureOr<void> deleteProduct(int id);
  FutureOr<void> updateProduct(int id, ProductDTO product);
}

class ProductsRepositoryImpl implements ProductsRepository {
  late Box<ProductHiveObject> box;

  @override
  Future<void> init() async {
    Hive.init('.');
    Hive.registerAdapter(ProductHiveObjectAdapter());
    box = await Hive.openBox('products');
    box.put(
      1,
      ProductHiveObject(
        title: 'Pen',
        description: 'Beatiful pens',
        price: 34.0,
        photo: 'pens.jpg',
      ),
    );
  }

  @override
  Future<void> dispose() => Hive.close();

  @override
  FutureOr<List<ProductDTO>> getProducts() => box
      .toMap()
      .entries
      .map((e) => ProductDTO.fromHive(e.key, e.value))
      .toList();

  @override
  FutureOr<ProductDTO?> getProduct(int id) {
    final value = box.get(id);
    if (value == null) return null;
    return ProductDTO.fromHive(id, value);
  }

  @override
  FutureOr<int> addProduct(ProductDTO product) => box.add(product.toHive());

  @override
  FutureOr<void> deleteProduct(int id) => box.delete(id);

  @override
  FutureOr<void> updateProduct(int id, ProductDTO product) =>
      box.put(id, product.toHive());
}

class ProductsApi {
  ProductsRepository repository;

  ProductsApi(this.repository);

  void _checkAuthorization(bool authorized, String path) {
    if (!authorized) {
      throw ProductsHTTPException(
          HttpStatus.unauthorized, Uri.parse(path), 'Authorization required');
    }
  }

  void _idNeeded(int? id, String path) {
    if (id == null) {
      throw ProductsHTTPException(
          HttpStatus.badRequest, Uri.parse(path), 'Product id is required');
    }
  }

  void _bodyNeeded(ProductDTO? body, String path) {
    if (body == null) {
      throw ProductsHTTPException(
          HttpStatus.badRequest, Uri.parse(path), 'Product data is required');
    }
  }

  Future<String?> _handle(
      String method, int? id, bool authorized, ProductDTO? body) async {
    switch (method) {
      case 'GET':
        if (id == null) {
          final products = await repository.getProducts();
          return jsonEncode(products);
        } else {
          final product = await repository.getProduct(id);
          if (product == null) {
            throw ProductsHTTPException(
                404, Uri.parse('/products/$id'), 'Product isn\'t found');
          }
          return jsonEncode(product);
        }
      case 'DELETE':
        _checkAuthorization(authorized, '/products/$id');
        _idNeeded(id, '/products');
        repository.deleteProduct(id!);
      case 'PUT':
        _checkAuthorization(authorized, '/products/$id');
        _idNeeded(id, '/products');
        _bodyNeeded(body, '/products/$id');
        repository.updateProduct(id!, body!);
      case 'POST':
        _checkAuthorization(authorized, '/products');
        _bodyNeeded(body, '/products/$id');
        repository.addProduct(body!);
      default:
        return null;
    }
  }

  Future<void> run() async {
    final server = await HttpServer.bind('0.0.0.0', 8080);
    await repository.init();
    await for (final request in server) {
      final uri = request.requestedUri;
      final segments = uri.pathSegments;
      if (segments[0] != 'product') {
        request.response.statusCode = HttpStatus.badRequest;
      } else {
        int? id = segments.length > 1 ? int.tryParse(segments[1]) : null;
        String method = request.method;
        developer.log('Request method: $method[$id]');
        ProductDTO? body;
        try {
          body = ProductDTO.fromJson(
              jsonDecode(await utf8.decoder.bind(request).join()));
          developer.log('Request body: $body');
        } catch (e) {
          body = null;
        }
        try {
          final authorized = request.headers['Authorization'] != null;
          final response = await _handle(method, id, authorized, body);
          developer.log('Response $method[$id] : $response');
          if (response != null) {
            request.response.write(response);
          }
        } on ProductsHTTPException catch (e) {
          developer
              .log('HTTP Exception, status: ${e.status} on URI: ${e.uri}: $e');
          request.response.statusCode = e.status;
          request.response.writeln(e.message);
          request.response.writeln('URI: ${e.uri.toString()}');
        }
      }
      await request.response.close();
    }
  }
}

void main(List<String> arguments) async =>
    ProductsApi(ProductsRepositoryImpl()).run();
