import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/country_flag.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../shop/storex_reviews_and_success_pages.dart';

enum ShippingMethod { free, flatRate, localPickup }

class ShippingAddress {
  String firstName = '';
  String lastName = '';
  String country = 'France';
  String state = '';
  String addressLine1 = '';
  String addressLine2 = '';
  String region = '';
  String zip = '';
  String email = '';
  String phone = '';

  bool get isValid =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      addressLine1.trim().isNotEmpty &&
      zip.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      phone.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'country': country.trim(),
        'state': state.trim(),
        'addressLine1': addressLine1.trim(),
        'addressLine2': addressLine2.trim(),
        'region': region.trim(),
        'zip': zip.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      };
}

class StorexCheckoutFlow {
  static Future<void> start(BuildContext context) async {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StorexDeliveryPage()));
  }
}

/// ==============================
/// PAGE 1 - DELIVERY
/// ==============================
class StorexDeliveryPage extends StatefulWidget {
  const StorexDeliveryPage({super.key});

  @override
  State<StorexDeliveryPage> createState() => _StorexDeliveryPageState();
}

class _StorexDeliveryPageState extends State<StorexDeliveryPage> {
  ShippingMethod shipping = ShippingMethod.flatRate;
  final addr = ShippingAddress();

  final _fn = TextEditingController();
  final _ln = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _zip = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late final TextEditingController _regionCtrl;

  String country = 'France';
  String state = '';
  String region = '';

  bool _loadingProfile = false;

  CollectionReference<Map<String, dynamic>> _shopProfileCol(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('shop_profile');
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loadingProfile = true);
    try {
      // Source: users/{uid}/shop_profile/shipping
      final doc = await _shopProfileCol(user.uid).doc('shipping').get();
      final data = doc.data();
      if (data == null) return;

      final raw = (data['shippingAddress'] is Map) ? (data['shippingAddress'] as Map) : data;
      String s(String k) => (raw[k] ?? '').toString();

      if (_fn.text.trim().isEmpty) _fn.text = s('firstName');
      if (_ln.text.trim().isEmpty) _ln.text = s('lastName');
      if (_addr1.text.trim().isEmpty) _addr1.text = s('addressLine1');
      if (_addr2.text.trim().isEmpty) _addr2.text = s('addressLine2');
      if (_zip.text.trim().isEmpty) _zip.text = s('zip');
      if (_phone.text.trim().isEmpty) _phone.text = s('phone');

      final email = s('email');
      final authEmail = user.email ?? '';
      if (_email.text.trim().isEmpty) {
        _email.text = email.trim().isNotEmpty ? email : authEmail;
      }

      final c = s('country').trim();
      final st = s('state').trim();
      final rg = s('region').trim();
      if (c.isNotEmpty) country = c;
      if (st.isNotEmpty) state = st;
      if (rg.isNotEmpty) {
        region = rg;
        _regionCtrl.text = rg;
      }

      _sync();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _shopProfileCol(user.uid).doc('shipping').set(
      {
        'shippingAddress': addr.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  void initState() {
    super.initState();
    _regionCtrl = TextEditingController(text: region);
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  int get shippingCents {
    switch (shipping) {
      case ShippingMethod.free:
        return 0;
      case ShippingMethod.flatRate:
        return 2000;
      case ShippingMethod.localPickup:
        return 500;
    }
  }

  String get shippingKey {
    switch (shipping) {
      case ShippingMethod.free:
        return 'free';
      case ShippingMethod.flatRate:
        return 'flat_rate';
      case ShippingMethod.localPickup:
        return 'local_pickup';
    }
  }

  void _sync() {
    addr
      ..firstName = _fn.text
      ..lastName = _ln.text
      ..country = country
      ..state = state
      ..region = region
      ..addressLine1 = _addr1.text
      ..addressLine2 = _addr2.text
      ..zip = _zip.text
      ..email = _email.text
      ..phone = _phone.text;
  }

  @override
  void dispose() {
    _fn.dispose();
    _ln.dispose();
    _addr1.dispose();
    _addr2.dispose();
    _zip.dispose();
    _email.dispose();
    _phone.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'DELIVERY',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          const Text(
            'Shipping Method',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShipBox(
                  top: '€0',
                  bottom: 'Free shipping',
                  selected: shipping == ShippingMethod.free,
                  onTap: () => setState(() => shipping = ShippingMethod.free),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShipBox(
                  top: '€20',
                  bottom: 'Flat rate',
                  selected: shipping == ShippingMethod.flatRate,
                  onTap: () => setState(() => shipping = ShippingMethod.flatRate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShipBox(
                  top: '€5',
                  bottom: 'Local pickup',
                  selected: shipping == ShippingMethod.localPickup,
                  onTap: () => setState(() => shipping = ShippingMethod.localPickup),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Your Delivery Address',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Field(ctrl: _fn, hint: 'John', onChanged: (_) => _sync())),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _ln, hint: 'Doe', onChanged: (_) => _sync())),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: country,
                  items: const ['France', 'Guadeloupe', 'Martinique', 'United States', 'Other'],
                  labelBuilder: formatCountryNameWithFlag,
                  onChanged: (v) => setState(() {
                    country = v;
                    _sync();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Dropdown(
                  value: state,
                  items: const ['', 'France (Métropole)', 'Guadeloupe', 'Martinique', 'Other'],
                  onChanged: (v) => setState(() {
                    state = v;
                    _sync();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(ctrl: _addr1, hint: 'Adresse (ligne 1)', onChanged: (_) => _sync()),
          const SizedBox(height: 12),
          _Field(ctrl: _addr2, hint: 'Adresse (ligne 2)', onChanged: (_) => _sync()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Field(
                  ctrl: _regionCtrl,
                  hint: 'Région (optionnel)',
                  readOnly: false,
                  onChanged: (v) {
                    region = v;
                    _sync();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  ctrl: _zip,
                  hint: 'Code postal',
                  keyboard: TextInputType.number,
                  onChanged: (_) => _sync(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            ctrl: _email,
            hint: 'Email',
            keyboard: TextInputType.emailAddress,
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 12),
          _Field(
            ctrl: _phone,
            hint: 'Téléphone',
            keyboard: TextInputType.phone,
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 18),
          if (_loadingProfile)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Chargement de vos coordonnées…',
                style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
              ),
            ),
          if (cart.isEmpty)
            const Text('Ton panier est vide.', style: TextStyle(color: Colors.black45))
          else
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F232A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  _sync();
                  if (!addr.isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Merci de compléter vos coordonnées (nom, adresse, email, téléphone).')),
                    );
                    return;
                  }
                  _saveProfile();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StorexPaymentPage(
                        shippingCents: shippingCents,
                        shippingMethodKey: shippingKey,
                        address: addr,
                      ),
                    ),
                  );
                },
                child: const Text('NEXT', style: TextStyle(letterSpacing: 0.6)),
              ),
            ),
        ],
      ),
    );
  }
}

class StorexPaymentPage extends StatefulWidget {
  const StorexPaymentPage({
    super.key,
    required this.shippingCents,
    required this.shippingMethodKey,
    required this.address,
  });

  final int shippingCents;
  final String shippingMethodKey;
  final ShippingAddress address;

  @override
  State<StorexPaymentPage> createState() => _StorexPaymentPageState();
}

/// ==============================
/// PAGE 2 - PAYMENT + Stripe PaymentSheet
/// ==============================
class _StorexPaymentPageState extends State<StorexPaymentPage> {
  bool loading = false;

  int _subtotalCents(List<CartItem> items) {
    var total = 0;
    for (final it in items) {
      total += it.priceCents * it.quantity;
    }
    return total;
  }

  String _money(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  Future<void> _pay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not signed in');

    final items = CartService.instance.items;
    if (items.isEmpty) throw Exception('Cart empty');

    setState(() => loading = true);
    try {
      // 1) Server creates order + paymentIntent
      final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('createStorexPaymentIntent');

      final res = await callable.call<Map<String, dynamic>>({
        'currency': 'eur',
        'shippingCents': widget.shippingCents,
        'shippingMethod': widget.shippingMethodKey,
        'address': widget.address.toMap(),
      });

      final data = res.data;
      final clientSecret = (data['clientSecret'] ?? '').toString();
      final orderId = (data['orderId'] ?? '').toString();

      if (clientSecret.isEmpty || orderId.isEmpty) {
        throw Exception('Missing clientSecret/orderId');
      }

      // 2) Init payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'MASLIVE',
          style: ThemeMode.light,
        ),
      );

      // 3) Present sheet
      await Stripe.instance.presentPaymentSheet();

      // 4) Mark order as processing (final status set by webhook)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'processing',
        'stripe.status': 'processing',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5) Clear cart (local + Firestore sync)
      CartService.instance.clear();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        StorexRoutes.paymentComplete,
        (r) => false,
        arguments: PaymentCompleteArgs(
          orderCode: orderId,
          continueToRoute: '/boutique',
        ),
      );
    } on StripeException catch (e) {
      final msg = e.error.localizedMessage ?? e.error.message ?? 'Stripe error';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment error: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = CartService.instance.items;
    final subtotal = _subtotalCents(items);
    final total = subtotal + widget.shippingCents;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'PAYMENT',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1F232A)),
            ),
            child: const Center(
              child: Text(
                'Stripe',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Line(label: 'Shipping', value: _money(widget.shippingCents)),
          const SizedBox(height: 10),
          _Line(label: 'Subtotal', value: _money(subtotal)),
          const SizedBox(height: 14),
          _Line(label: 'Total', value: _money(total), bold: true),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F232A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: loading ? null : _pay,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('CONFIRM ORDER',
                      style: TextStyle(letterSpacing: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.black87,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.black45))),
        Text(value, style: style),
      ],
    );
  }
}

class _ShipBox extends StatelessWidget {
  const _ShipBox({
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
  });
  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF1F232A) : Colors.white;
    final border = selected ? const Color(0xFF1F232A) : const Color(0x22000000);
    final text = selected ? Colors.white : Colors.black87;
    final sub = selected ? Colors.white70 : Colors.black45;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(top, style: TextStyle(color: text, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(bottom, style: TextStyle(color: sub, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.hint,
    this.keyboard,
    this.readOnly = false,
    this.onChanged,
  });
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboard;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      readOnly: readOnly,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0x22000000)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0x22000000)),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String Function(String value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x22000000))),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black45),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(labelBuilder?.call(e) ?? e),
              ),
            )
            .toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }
}
