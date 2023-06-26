// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sampleapi.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductHiveObjectAdapter extends TypeAdapter<ProductHiveObject> {
  @override
  final int typeId = 0;

  @override
  ProductHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductHiveObject(
      title: fields[0] as String,
      description: fields[1] as String,
      price: fields[2] as double,
      photo: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductHiveObject obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.photo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductDTO _$ProductDTOFromJson(Map<String, dynamic> json) => ProductDTO(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      photo: json['photo'] as String?,
    );

Map<String, dynamic> _$ProductDTOToJson(ProductDTO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'price': instance.price,
      'photo': instance.photo,
    };
