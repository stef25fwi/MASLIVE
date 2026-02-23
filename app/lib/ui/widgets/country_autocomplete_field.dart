import 'package:flutter/material.dart';

import '../../models/market_country.dart';
import '../../services/market_map_service.dart';
import '../../utils/country_flag.dart';

typedef CountryTextFormatter = String Function(String name);

class CountryNameAutocompleteField extends StatefulWidget {
  const CountryNameAutocompleteField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelText = 'Pays',
    this.hintText,
    this.enabled = true,
  });

  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final String? hintText;
  final bool enabled;

  @override
  State<CountryNameAutocompleteField> createState() => _CountryNameAutocompleteFieldState();
}

class _CountryNameAutocompleteFieldState extends State<CountryNameAutocompleteField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(CountryNameAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value ?? '';
    if (next != _ctrl.text) {
      _ctrl.text = next;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Iterable<String> _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((c) => c.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _ctrl,
      focusNode: _focus,
      optionsBuilder: (value) => _filter(value.text),
      displayStringForOption: (o) => o,
      onSelected: (value) {
        widget.onChanged(value);
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => widget.onChanged(v.trim().isEmpty ? null : v),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final c = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(formatCountryNameWithFlag(c)),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class CountryNameAutocompleteFormField extends StatefulWidget {
  const CountryNameAutocompleteFormField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelText = 'Pays',
    this.hintText,
    this.enabled = true,
    this.validator,
  });

  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final String? hintText;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  @override
  State<CountryNameAutocompleteFormField> createState() => _CountryNameAutocompleteFormFieldState();
}

class _CountryNameAutocompleteFormFieldState extends State<CountryNameAutocompleteFormField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(CountryNameAutocompleteFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value ?? '';
    if (next != _ctrl.text) {
      _ctrl.text = next;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Iterable<String> _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((c) => c.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        return RawAutocomplete<String>(
          textEditingController: _ctrl,
          focusNode: _focus,
          optionsBuilder: (value) => _filter(value.text),
          displayStringForOption: (o) => o,
          onSelected: (value) {
            field.didChange(value);
            widget.onChanged(value);
          },
          fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textCtrl,
              focusNode: focusNode,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
                errorText: field.errorText,
              ),
              onChanged: (v) {
                final value = v.trim().isEmpty ? null : v;
                field.didChange(value);
                widget.onChanged(value);
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 280),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final c = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(formatCountryNameWithFlag(c)),
                        onTap: () => onSelected(c),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MarketCountryAutocompleteField extends StatefulWidget {
  const MarketCountryAutocompleteField({
    super.key,
    required this.items,
    required this.controller,
    required this.onSelected,
    this.labelText = 'Pays',
    this.hintText,
    this.enabled = true,
    this.valueForOption,
  });

  final List<MarketCountry> items;
  final TextEditingController controller;
  final ValueChanged<MarketCountry?> onSelected;
  final String labelText;
  final String? hintText;
  final bool enabled;
  final String Function(MarketCountry)? valueForOption;

  @override
  State<MarketCountryAutocompleteField> createState() => _MarketCountryAutocompleteFieldState();
}

class _MarketCountryAutocompleteFieldState extends State<MarketCountryAutocompleteField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String _label(MarketCountry c) {
    final name = c.name.trim();
    return name.isNotEmpty ? name : c.id;
  }

  Iterable<MarketCountry> _filter(String query) {
    final q = MarketMapService.slugify(query);
    if (q.isEmpty) return widget.items;
    return widget.items.where((c) {
      final labelSlug = MarketMapService.slugify(_label(c));
      final idSlug = MarketMapService.slugify(c.id);
      return labelSlug.contains(q) || idSlug.contains(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<MarketCountry>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) => _filter(value.text),
      displayStringForOption: _label,
      onSelected: (c) {
        widget.controller.text = widget.valueForOption?.call(c) ?? _label(c);
        widget.onSelected(c);
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => widget.onSelected(null),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final c = options.elementAt(i);
                  final iso2 = guessIso2FromMarketMapCountry(
                    id: c.id,
                    slug: c.slug,
                    name: c.name,
                  );
                  return ListTile(
                    dense: true,
                    title: Text(formatCountryLabelWithFlag(name: _label(c), iso2: iso2)),
                    subtitle: (c.id.trim().isEmpty || c.id.trim() == _label(c)) ? null : Text(c.id),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
