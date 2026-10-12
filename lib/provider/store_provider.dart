import 'package:flutter/material.dart';

class StoreProvider extends ChangeNotifier {
  String? _selectedStoreId;
  String? _selectedStoreName;
  double? _selectedStoreDistance;

  String? get selectedStoreId => _selectedStoreId;
  String? get selectedStoreName => _selectedStoreName;
  double? get selectedStoreDistance => _selectedStoreDistance;

  void setSelectedStore(String id, {String? name, double? distance}) {
    _selectedStoreId = id;
    _selectedStoreName = name;
    _selectedStoreDistance = distance;
    notifyListeners();
  }

  void clearStore() {
    _selectedStoreId = null;
    _selectedStoreName = null;
    _selectedStoreDistance = null;
    notifyListeners();
  }
}