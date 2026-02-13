import 'package:muzik/models/category.dart'; // Bu importu eklemen lazım

class CategoryOpration {
  CategoryOpration() {}
  static List<Category> getCategories() {
    // Dönüş tipini List<Category> olarak belirtmek iyidir
    return <Category>[
      Category(
        'top songs',
        'https://miniflakey.com/wp-content/uploads/2023/05/TopSongs_AppIcon.png',
      ),
      Category(
        'mj hits',
        'https://miniflakey.com/wp-content/uploads/2023/05/TopSongs_AppIcon.png',
      ),
      Category(
        'top songs',
        'https://miniflakey.com/wp-content/uploads/2023/05/TopSongs_AppIcon.png',
      ),
      Category(
        'mj hits',
        'https://miniflakey.com/wp-content/uploads/2023/05/TopSongs_AppIcon.png',
      ),
    ];
  }
}
