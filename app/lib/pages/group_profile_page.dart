import 'package:flutter/material.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';
import 'shop_page.dart';

class GroupProfilePage extends StatefulWidget {
  const GroupProfilePage({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  @override
  Widget build(BuildContext context) {
    final group = _MockGroup.byId(widget.groupId);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: HoneycombBackground(
          opacity: 0.08,
          child: Column(
            children: [
              MasliveGradientHeader(
                height: 250,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: MasliveTheme.textPrimary,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ShopPixelPerfectPage(groupId: widget.groupId)),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag_outlined),
                          color: MasliveTheme.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MasliveCard(
                      radius: 22,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 124,
                              width: double.infinity,
                              child: Image.asset(
                                'assets/splash/maslive.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: MasliveTheme.surfaceAlt,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.0),
                                      Colors.black.withValues(alpha: 0.22),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 12,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${group.city} · ${group.membersCount} membres',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.white.withValues(alpha: 0.86),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.90),
                                      foregroundColor: MasliveTheme.textPrimary,
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Suivre (mock)')),
                                      );
                                    },
                                    child: const Text('Suivre'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                    color: const Color(0x14FF6BB5),
                    border: Border.all(color: MasliveTheme.divider),
                    boxShadow: MasliveTheme.cardShadow,
                  ),
                  labelColor: MasliveTheme.textPrimary,
                  unselectedLabelColor: MasliveTheme.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(text: 'À propos'),
                    Tab(text: 'Planning'),
                    Tab(text: 'Médias'),
                    Tab(text: 'Membres'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    _AboutTab(group: group),
                    _PlanningTab(group: group),
                    _MediaTab(group: group),
                    _MembersTab(group: group),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _AboutTab extends StatelessWidget {
  final _MockGroup group;
  const _AboutTab({required this.group});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      children: [
        MasliveCard(
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('À propos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(group.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MasliveTheme.textSecondary)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.tags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                          color: MasliveTheme.surfaceAlt,
                          border: Border.all(color: MasliveTheme.divider),
                        ),
                        child: Text(t, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MasliveCard(
          radius: 20,
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: MasliveTheme.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Localisation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(group.city, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MasliveTheme.textSecondary)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Voir'),
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanningTab extends StatelessWidget {
  final _MockGroup group;
  const _PlanningTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _MockEvent(day: 'Samedi', title: 'Sortie ville', time: '10:00', note: 'Point de rendez-vous: Place centrale'),
      const _MockEvent(day: 'Dimanche', title: 'Session tracking', time: '16:30', note: 'Live + replay dans Médias'),
      const _MockEvent(day: 'Mercredi', title: 'Food & chill', time: '20:00', note: 'Restaurant sélectionné par vote'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final e = items[i];
        return MasliveCard(
          radius: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: MasliveTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MasliveTheme.divider),
                ),
                child: Column(
                  children: [
                    Text(e.day.substring(0, 3).toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(e.time, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MasliveTheme.textSecondary, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(e.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MasliveTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaTab extends StatelessWidget {
  final _MockGroup group;
  const _MediaTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final assets = [
      'assets/splash/maslive.png',
      'assets/splash/maslivepinky.png',
      'assets/splash/maslivesmall.png',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: GridView.builder(
        itemCount: assets.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, i) {
          final a = assets[i];
          return MasliveCard(
            radius: 22,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                a,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: MasliveTheme.surfaceAlt),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MembersTab extends StatelessWidget {
  final _MockGroup group;
  const _MembersTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final members = [
      const _MockMember(name: 'Nina', role: 'Admin'),
      const _MockMember(name: 'Kévin', role: 'Modérateur'),
      const _MockMember(name: 'Sacha', role: 'Membre'),
      const _MockMember(name: 'Lina', role: 'Membre'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final m = members[i];
        return MasliveCard(
          radius: 20,
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: MasliveTheme.actionGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: MasliveTheme.cardShadow,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white),
            ),
            title: Text(m.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            subtitle: Text(m.role, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MasliveTheme.textSecondary)),
            trailing: Icon(Icons.more_horiz_rounded, color: MasliveTheme.textSecondary),
          ),
        );
      },
    );
  }
}

class _MockGroup {
  final String id;
  final String name;
  final String city;
  final int membersCount;
  final String description;
  final List<String> tags;

  const _MockGroup({
    required this.id,
    required this.name,
    required this.city,
    required this.membersCount,
    required this.description,
    required this.tags,
  });

  static _MockGroup byId(String id) {
    return _MockGroup(
      id: id,
      name: 'MASLIVE Crew',
      city: 'Pointe-à-Pitre',
      membersCount: 128,
      description:
          "Communauté premium MASLIVE : sorties, tracking et contenus exclusifs.\n" "Un style clean, pastel, et une expérience fluide — version mockup.",
      tags: const ['Ville', 'Tracking', 'Médias', 'Food'],
    );
  }
}

class _MockEvent {
  final String day;
  final String title;
  final String time;
  final String note;

  const _MockEvent({
    required this.day,
    required this.title,
    required this.time,
    required this.note,
  });
}

class _MockMember {
  final String name;
  final String role;

  const _MockMember({
    required this.name,
    required this.role,
  });
}
