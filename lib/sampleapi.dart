import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import 'dart:developer' as developer;

import 'package:shelf/shelf_io.dart';
import 'package:shelf_open_api/shelf_open_api.dart';
import 'package:shelf_plus/shelf_plus.dart';
import 'package:shelf_swagger_ui/shelf_swagger_ui.dart';

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

  // Handler _getRoutes() {
  //   final app = RouterPlus();
  //   app.use(logger);
  //   app.use(auth);
  //   app.get('/product',
  //       () async => (await repository.getProducts()).map((e) => e.toJson()));
  //   app.get('/product/<id>', (Request req, String id) {
  //     final result = repository.getProduct(int.tryParse(id) ?? 0);
  //     if (result == null) return Response.notFound('Product isn\'t found');
  //     return result;
  //   });
  //   app.post('/product', (Request request) async {
  //     repository.addProduct(
  //         ProductDTO.fromJson(jsonDecode(await request.readAsString())));
  //     return Response.ok('');
  //   });
  //   app.put('/product/<id>', (Request request, String id) async {
  //     repository.updateProduct(int.tryParse(id) ?? 0,
  //         ProductDTO.fromJson(jsonDecode(await request.readAsString())));
  //   });
  //   app.delete('/product/<id>', (Request request, String id) async {
  //     repository.deleteProduct(int.tryParse(id) ?? 0);
  //   });
  //   return app;
  // }

  Future<void> run() async {
    await repository.init();
    await serve(ProductsController(repository).router, '0.0.0.0', 8080);
  }
}

Middleware get auth => createMiddleware(requestHandler: (request) {
      if (request.method == 'GET') return null;
      if (!request.headers.containsKey('Authorization')) {
        return Response.unauthorized('You need to be authorized user');
      }
      return null;
    });

Middleware get logger => createMiddleware(
      requestHandler: (request) {
        developer.log('Request ${request.method} ${request.url.path}');
        return null; //здесь может быть Response
      },
      responseHandler: (response) async {
        if (['text/plain', 'application/json'].contains(response.mimeType)) {
          final content = await response.readAsString();
          developer.log('Response $content');
          return response.change(body: content);
        } else {
          return response;
        }
      },
    );

class ProductsController {
  ProductsRepository repository;
  ProductsController(this.repository);

  Response toJson(dynamic data) => Response.ok(jsonEncode(data));

  //Get products list
  //
  //Get all the products
  //You can write the long description here
  @Route('GET', '/product')
  @OpenApiRoute()
  Future<Response> getProducts(Request request) async =>
      toJson((await repository.getProducts()).map((e) => e.toJson()).toList());

  //Get product with given id
  @Route('GET', '/product/<id>')
  @OpenApiRoute()
  Future<Response> getProduct(Request request, String id) async =>
      toJson((await repository.getProduct(int.tryParse(id) ?? 0)));

  //Create new product
  @Route('POST', '/product')
  @OpenApiRoute(requestBody: ProductDTO)
  Future<Response> createProduct(Request request) async {
    final data = jsonDecode(await request.readAsString());
    repository.addProduct(ProductDTO.fromJson(data));
    return Response.ok('');
  }

  //Delete product
  @Route('DELETE', '/product/<id>')
  @OpenApiRoute()
  Future<Response> deleteProduct(Request request, String id) async {
    repository.deleteProduct(int.tryParse(id) ?? 0);
    return Response.ok('');
  }

  //Update product
  @Route('PUT', '/product/<id>')
  @OpenApiRoute(requestBody: ProductDTO)
  Future<Response> updateProduct(Request request, String id) async {
    final data = jsonDecode(await request.readAsString());
    repository.updateProduct(int.tryParse(id) ?? 0, data);
    return Response.ok('');
  }

  RouterPlus get router => _$ProductsControllerRouter(this).plus
    ..use(logger)
    // ..use(auth)
    ..mount('/swagger',
        SwaggerUI('public/sample.open_api.yaml', title: 'Swagger API'))
    ..mount('/', createStaticHandler('public'));
}
