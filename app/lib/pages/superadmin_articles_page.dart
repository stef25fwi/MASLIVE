import 'package:flutter/material.dart';
import '../models/superadmin_article.dart';
import '../services/superadmin_article_service.dart';
import '../widgets/rainbow_header.dart';
import '../ui/widgets/honeycomb_background.dart';

class SuperadminArticlesPage extends StatefulWidget {
  const SuperadminArticlesPage({super.key});

  @override
  State<SuperadminArticlesPage> createState() => _SuperadminArticlesPageState();
}

class _SuperadminArticlesPageState extends State<SuperadminArticlesPage> {
  final SuperadminArticleService _articleService = SuperadminArticleService();
  
  String _selectedCategory = 'tous'; // tous, casquette, tshirt, porteclé, bandana

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoneycombBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: RainbowHeader(
                title: 'Mes articles en ligne',
                leading: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Filtre par catégorie
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildCategoryFilter(),
              ),
            ),
            // Bouton ajouter
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un article'),
                  onPressed: _showAddArticleDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            // Liste des articles
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: StreamBuilder<List<SuperadminArticle>>(
                stream: _articleService.streamActiveArticles(
                  category: _selectedCategory == 'tous' ? null : _selectedCategory,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Aucun article trouvé',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final article = snapshot.data![index];
                        return _buildArticleCard(article);
                      },
                      childCount: snapshot.data!.length,
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['tous', ...SuperadminArticleService.validCategories];
    
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category[0].toUpperCase() + category.substring(1),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.deepPurple.shade50,
              side: BorderSide(
                color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.deepPurple : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticleCard(SuperadminArticle article) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey.shade200,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: article.imageUrl.isNotEmpty
                    ? Image.network(
                        article.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.image, size: 32, color: Colors.grey.shade400),
                          );
                        },
                      )
                    : Center(
                        child: Icon(Icons.image, size: 32, color: Colors.grey.shade400),
                      ),
              ),
            ),
          ),
          // Infos
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${article.price.toStringAsFixed(2)}€',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stock: ${article.stock}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                    InkWell(
                      onTap: () => _showArticleMenu(article),
                      child: const Icon(Icons.more_vert, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showArticleMenu(SuperadminArticle article) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _showEditArticleDialog(article);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Mettre à jour le stock'),
              onTap: () {
                Navigator.pop(context);
                _showUpdateStockDialog(article);
              },
            ),
            ListTile(
              leading: Icon(
                article.isActive ? Icons.visibility_off : Icons.visibility,
              ),
              title: Text(article.isActive ? 'Désactiver' : 'Activer'),
              onTap: () async {
                Navigator.pop(context);
                await _articleService.toggleArticleStatus(article.id, !article.isActive);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(article);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddArticleDialog() {
    showDialog(
      context: context,
      builder: (context) => _ArticleEditDialog(
        onSave: (article) async {
          try {
            await _articleService.createArticle(
              name: article['name'],
              description: article['description'],
              category: article['category'],
              price: article['price'],
              imageUrl: article['imageUrl'],
              stock: article['stock'],
              sku: article['sku'],
            );
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Article créé avec succès')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Erreur: $e')),
            );
          }
        },
      ),
    );
  }

  void _showEditArticleDialog(SuperadminArticle article) {
    showDialog(
      context: context,
      builder: (context) => _ArticleEditDialog(
        article: article,
        onSave: (updatedData) async {
          try {
            final updated = article.copyWith(
              name: updatedData['name'],
              description: updatedData['description'],
              category: updatedData['category'],
              price: updatedData['price'],
              imageUrl: updatedData['imageUrl'],
              stock: updatedData['stock'],
              sku: updatedData['sku'],
            );
            
            await _articleService.updateArticle(article.id, updated);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Article mis à jour')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Erreur: $e')),
            );
          }
        },
      ),
    );
  }

  void _showUpdateStockDialog(SuperadminArticle article) {
    final controller = TextEditingController(text: article.stock.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mettre à jour le stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Nouveau stock',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final newStock = int.parse(controller.text);
                await _articleService.updateStock(article.id, newStock);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Stock mis à jour')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Erreur: $e')),
                );
              }
            },
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(SuperadminArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'article?'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${article.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _articleService.deleteArticle(article.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Article supprimé')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Erreur: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

/// Dialog pour éditer/créer un article
class _ArticleEditDialog extends StatefulWidget {
  final SuperadminArticle? article;
  final Function(Map<String, dynamic>) onSave;

  const _ArticleEditDialog({
    this.article,
    required this.onSave,
  });

  @override
  State<_ArticleEditDialog> createState() => _ArticleEditDialogState();
}

class _ArticleEditDialogState extends State<_ArticleEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _skuController;
  late String _selectedCategory;
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.article?.name ?? '');
    _descriptionController = TextEditingController(text: widget.article?.description ?? '');
    _priceController = TextEditingController(text: widget.article?.price.toString() ?? '');
    _stockController = TextEditingController(text: widget.article?.stock.toString() ?? '');
    _skuController = TextEditingController(text: widget.article?.sku ?? '');
    _selectedCategory = widget.article?.category ?? 'casquette';
    _imageUrl = widget.article?.imageUrl ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.article == null ? 'Ajouter un article' : 'Modifier l\'article'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image preview
            if (_imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrl,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: 120,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image),
                      );
                    },
                  ),
                ),
              ),
            
            // Champs
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom*'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: SuperadminArticleService.validCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat[0].toUpperCase() + cat.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Catégorie*'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix (€)*'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock*'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Le nom est requis')),
              );
              return;
            }

            widget.onSave({
              'name': name,
              'description': _descriptionController.text.trim(),
              'category': _selectedCategory,
              'price': double.tryParse(_priceController.text) ?? 0.0,
              'stock': int.tryParse(_stockController.text) ?? 0,
              'sku': _skuController.text.trim(),
              'imageUrl': _imageUrl,
            });

            Navigator.pop(context);
          },
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }
}
