import 'package:firebase_database/firebase_database.dart';
import '../models/category_model.dart';

class CategoryService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref('categories');

  // Get all parent categories (where parentId is null)
  Stream<List<Category>> getParentCategories() {
    return _database.orderByChild('parentId').equalTo(null).onValue.map((event) {
      if (event.snapshot.value == null) return <Category>[];
      
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        return Category.fromMap(entry.key, Map<String, dynamic>.from(entry.value as Map));
      }).toList();
    });
  }

  // Get subcategories for a parent category
  Stream<List<Category>> getSubcategories(String parentId) {
    return _database.orderByChild('parentId').equalTo(parentId).onValue.map((event) {
      if (event.snapshot.value == null) return <Category>[];
      
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        return Category.fromMap(entry.key, Map<String, dynamic>.from(entry.value as Map));
      }).toList();
    });
  }
}
