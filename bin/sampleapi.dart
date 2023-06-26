import 'package:sampleapi/sampleapi.dart';

void main(List<String> arguments) async =>
    ProductsApi(ProductsRepositoryImpl()).run();
