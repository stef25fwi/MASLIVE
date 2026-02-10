import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ===============================================================
/// ROUTES (a enregistrer dans MaterialApp.routes)
/// ===============================================================
/// StorexRoutes.paymentComplete  -> args: PaymentCompleteArgs
/// StorexRoutes.reviews         -> args: ReviewsArgs
/// StorexRoutes.addReview       -> args: AddReviewArgs
/// StorexRoutes.orderTracker    -> args: OrderTrackerArgs
class StorexRoutes {
  static const paymentComplete = '/storex/paymentComplete';
  static const reviews = '/storex/reviews';
  static const addReview = '/storex/addReview';
  static const orderTracker = '/storex/orderTracker';
}

/// Pour pouvoir push avec arguments type-safe
class PaymentCompleteArgs {
  final String orderCode; // ex: SX133
  final String? continueToRoute; // ex: '/shop'
  const PaymentCompleteArgs({required this.orderCode, this.continueToRoute});
}

class ReviewsArgs {
  final String productId;
  final String productTitle;
  const ReviewsArgs({required this.productId, required this.productTitle});
}

class AddReviewArgs {
  final String productId;
  final String productTitle;
  const AddReviewArgs({required this.productId, required this.productTitle});
}

class OrderTrackerArgs {
  final String orderId;
  const OrderTrackerArgs({required this.orderId});
}

/// ===============================================================
/// FIRESTORE SCHEMA RECOMMANDE (simple & clean)
/// ===============================================================
/// products/{productId}/reviews/{reviewId}
/// fields:
///  - uid: string
///  - authorName: string
///  - rating: number (1..5)
///  - comment: string
///  - createdAt: Timestamp
class ReviewsRepository {
  static CollectionReference<Map<String, dynamic>> _reviewsCol(String productId) {
    return FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .collection('reviews');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamReviews(String productId) {
    return _reviewsCol(productId).orderBy('createdAt', descending: true).snapshots();
  }

  static Future<void> addReview({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final authorName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'user';

    await _reviewsCol(productId).add({
      'uid': user.uid,
      'authorName': authorName,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// ===============================================================
/// 1) PAYMENT COMPLETE PAGE (comme screenshot)
/// ===============================================================
class PaymentCompletePage extends StatelessWidget {
  const PaymentCompletePage({
    super.key,
    required this.orderCode,
    this.continueToRoute,
  });

  final String orderCode;
  final String? continueToRoute;

  static Route routeFromArgs(Object? args) {
    final a = args as PaymentCompleteArgs;
    return MaterialPageRoute(
      builder: (_) => PaymentCompletePage(
        orderCode: a.orderCode,
        continueToRoute: a.continueToRoute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = const Color(0xFF1F232A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const _CheckIcon(),
            const SizedBox(height: 18),
            const Text(
              'PAYMENT COMPLETE',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Order code is #$orderCode',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check the delivery status at',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Order Tracker Page',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  StorexRoutes.orderTracker,
                  arguments: OrderTrackerArgs(orderId: orderCode),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: const Text(
                'Open Order Tracker',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    if (continueToRoute != null) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        continueToRoute!,
                        (r) => false,
                      );
                    } else {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  child: const Text(
                    'CONTINUE SHOPPING',
                    style: TextStyle(letterSpacing: 0.7, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1F232A), width: 3),
      ),
      child: const Center(
        child: Icon(Icons.check, size: 42, color: Color(0xFF1F232A)),
      ),
    );
  }
}

/// ===============================================================
/// 1b) ORDER TRACKER PAGE (simple)
/// ===============================================================
class OrderTrackerPage extends StatelessWidget {
  const OrderTrackerPage({super.key, required this.orderId});

  final String orderId;

  static Route routeFromArgs(Object? args) {
    final a = args as OrderTrackerArgs;
    return MaterialPageRoute(
      builder: (_) => OrderTrackerPage(orderId: a.orderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Please sign in to view your order.')),
      );
    }

    final orderRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .doc(orderId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Order Tracker',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Erreur de chargement'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('Order not found.'));
          }

          final status = (data['status'] ?? 'pending').toString();
          final totalCents = (data['totalCents'] ?? 0) as int;
          final shippingMethod = (data['shippingMethod'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              _InfoRow(label: 'Order ID', value: orderId),
              _InfoRow(label: 'Status', value: status),
              _InfoRow(label: 'Shipping', value: shippingMethod),
              _InfoRow(label: 'Total', value: _formatCents(totalCents)),
              const SizedBox(height: 18),
              const Text(
                'We will update your delivery status here.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatCents(int cents) {
    return '€${(cents / 100).toStringAsFixed(2)}';
  }
}

/// ===============================================================
/// 2) REVIEWS PAGE (liste + bouton +)
/// ===============================================================
class ReviewsPage extends StatelessWidget {
  const ReviewsPage({
    super.key,
    required this.productId,
    required this.productTitle,
  });

  final String productId;
  final String productTitle;

  static Route routeFromArgs(Object? args) {
    final a = args as ReviewsArgs;
    return MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReviewsPage(productId: a.productId, productTitle: a.productTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Reviews',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black54),
            onPressed: () {
              Navigator.of(context).pushNamed(
                StorexRoutes.addReview,
                arguments: AddReviewArgs(productId: productId, productTitle: productTitle),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ReviewsRepository.streamReviews(productId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Erreur de chargement'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucun avis pour le moment.',
                style: TextStyle(color: Colors.black45),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final author = (d['authorName'] ?? 'user').toString();
              final comment = (d['comment'] ?? '').toString();
              final rating = (d['rating'] ?? 0) is int
                  ? d['rating'] as int
                  : (d['rating'] as num).round();

              final ts = d['createdAt'];
              final dateStr = _formatDate(ts);

              return _ReviewTile(
                author: author,
                rating: rating.clamp(0, 5),
                comment: comment,
                date: dateStr,
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$mm-$dd-$yyyy $hh:$min';
    }
    return '';
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.author,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String author;
  final int rating;
  final String comment;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                author,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),
            _StarRating(value: rating, size: 16),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          comment,
          style: const TextStyle(color: Colors.black54, height: 1.35),
        ),
        const SizedBox(height: 10),
        Text(
          date,
          style: const TextStyle(color: Colors.black38, fontSize: 12),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black45))),
          Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// ===============================================================
/// 3) ADD REVIEW PAGE (stars + textarea + submit)
/// ===============================================================
class AddReviewPage extends StatefulWidget {
  const AddReviewPage({
    super.key,
    required this.productId,
    required this.productTitle,
  });

  final String productId;
  final String productTitle;

  static Route routeFromArgs(Object? args) {
    final a = args as AddReviewArgs;
    return MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddReviewPage(productId: a.productId, productTitle: a.productTitle),
    );
  }

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  int rating = 4;
  final commentCtrl = TextEditingController(text: 'Nice job.');
  bool loading = false;

  @override
  void dispose() {
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final txt = commentCtrl.text.trim();
    if (rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis une note')));
      return;
    }
    if (txt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoute un commentaire')));
      return;
    }

    setState(() => loading = true);
    try {
      await ReviewsRepository.addReview(
        productId: widget.productId,
        rating: rating,
        comment: txt,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avis envoye ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = const Color(0xFF1F232A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Add Review',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          const Text('Rating', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _StarPicker(
            value: rating,
            onChanged: (v) => setState(() => rating = v),
          ),
          const SizedBox(height: 18),
          const Text('Comment', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x22000000)),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: commentCtrl,
              maxLines: 7,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: loading ? null : _submit,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SUBMIT', style: TextStyle(letterSpacing: 0.7, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// STARS (UI identique style screenshot)
/// ===============================================================
class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, this.size = 18});
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: Colors.black87,
        );
      }),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final idx = i + 1;
        final filled = idx <= value;
        return IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(idx),
          icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.black87),
        );
      }),
    );
  }
}
