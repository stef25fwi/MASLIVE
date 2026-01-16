import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'offers/offer_detail_v2_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedCity = 'Tous';
  String _selectedCategory = 'Tous';
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _search = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MasLive'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('offers')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: () async {
                await FirebaseFirestore.instance.collection('offers').get();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Erreur de chargement des offres')),
                ],
              ),
            );
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await FirebaseFirestore.instance.collection('offers').get();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Aucune offre disponible pour le moment.')),
                ],
              ),
            );
          }

          String _s(dynamic v) => (v ?? '').toString().trim();
          String pickTitle(Map<String, dynamic> d) =>
              _s(d['title']).isNotEmpty ? _s(d['title']) : (_s(d['name']).isNotEmpty ? _s(d['name']) : 'Annonce');
          String pickSubtitle(Map<String, dynamic> d) {
            final loc = _s(d['location']).isNotEmpty ? _s(d['location']) : _s(d['city']);
            final price = d['budget'] ?? d['price'] ?? d['amount'];
            final priceStr = price is num ? '${price.toDouble().toStringAsFixed(0)} €' : _s(price);
            if (loc.isEmpty && priceStr.isEmpty) return '';
            if (loc.isEmpty) return priceStr;
            if (priceStr.isEmpty) return loc;
            return '$loc • $priceStr';
          }
          String? pickThumb(Map<String, dynamic> d) {
            final images = d['imageUrls'] ?? d['photos'] ?? d['images'];
            if (images is List && images.isNotEmpty) {
              final first = images.first;
              if (first is String && first.trim().isNotEmpty) return first.trim();
            }
            return null;
          }
          String pickCity(Map<String, dynamic> d) {
            final loc = _s(d['location']);
            if (loc.isNotEmpty) return loc;
            final city = _s(d['city']);
            if (city.isNotEmpty) return city;
            return '';
          }
          String pickCategory(Map<String, dynamic> d) {
            final c = _s(d['category']);
            if (c.isNotEmpty) return c;
            final c2 = _s(d['categorie']);
            if (c2.isNotEmpty) return c2;
            return '';
          }
          bool matchesSearch(Map<String, dynamic> d) {
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            return [
              pickTitle(d),
              pickCity(d),
              pickCategory(d),
              _s(d['description']),
            ].any((s) => s.toLowerCase().contains(q));
          }

          // Construit les listes de filtres à partir des données affichées
          final cities = <String>{'Tous'};
          final categories = <String>{'Tous'};
          for (final doc in docs) {
            cities.add(pickCity(doc.data()));
            categories.add(pickCategory(doc.data()));
          }

          // Applique les filtres côté client pour robustesse (données hétérogènes)
          final filtered = docs.where((doc) {
            final d = doc.data();
            final city = pickCity(d);
            final cat = pickCategory(d);
            final okCity = _selectedCity == 'Tous' || city == _selectedCity;
            final okCat = _selectedCategory == 'Tous' || cat == _selectedCategory;
            final okSearch = matchesSearch(d);
            return okCity && okCat && okSearch;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await FirebaseFirestore.instance.collection('offers').get();
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filtered.length + 2,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher (titre, ville, catégorie)...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  );
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DropdownFilter(
                            label: 'Ville',
                            value: _selectedCity,
                            items: cities.where((e) => e.isNotEmpty).toList()..sort(),
                            onChanged: (v) => setState(() => _selectedCity = v ?? 'Tous'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DropdownFilter(
                            label: 'Catégorie',
                            value: _selectedCategory,
                            items: categories.where((e) => e.isNotEmpty).toList()..sort(),
                            onChanged: (v) => setState(() => _selectedCategory = v ?? 'Tous'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final doc = filtered[index - 2];
                final data = doc.data();
                final title = pickTitle(data);
                final subtitle = pickSubtitle(data);
                final thumb = pickThumb(data);
                final cat = pickCategory(data);
                final heroTag = 'offer-thumb-${doc.id}';
                return ListTile(
                  leading: thumb == null
                      ? const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFEFF2F7),
                          child: Icon(Icons.local_offer_outlined, color: Color(0xFF111827)),
                        )
                      : Hero(
                          tag: heroTag,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: CachedNetworkImage(
                              imageUrl: thumb,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFFF3F4F6),
                              ),
                              errorWidget: (_, __, ___) => const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFFEFF2F7),
                                child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF111827)),
                              ),
                            ),
                          ),
                        ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (cat.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _CategoryBadge(text: cat),
                      ],
                    ],
                  ),
                  subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfferDetailV2Page(offerId: doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fullItems = ['Tous', ...items.where((e) => e != 'Tous')];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: fullItems
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e.isEmpty ? '—' : e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;
  const _CategoryBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7DEE8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF243041),
        ),
      ),
    );
  }
}
