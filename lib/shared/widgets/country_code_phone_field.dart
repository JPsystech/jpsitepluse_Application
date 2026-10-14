import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sitepulse_engineer/shared/models/country_code.dart';

class CountryCodePhoneField extends StatelessWidget {
  final TextEditingController controller;
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountryChanged;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  const CountryCodePhoneField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.labelText = "Mobile Number *",
    this.hintText,
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
  });

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(
        selectedCountry: selectedCountry,
        onSelected: (country) {
          Navigator.of(ctx).pop();
          onCountryChanged(country);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIndia = selectedCountry.iso == 'IN';
    final dynamicHint = hintText ?? (isIndia ? "10-digit mobile number" : "Mobile number");
    final dynamicMaxLength = isIndia ? 10 : 15;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(dynamicMaxLength),
      ],
      decoration: InputDecoration(
        labelText: labelText,
        hintText: dynamicHint,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        prefixIcon: InkWell(
          onTap: enabled ? () => _showCountryPicker(context) : null,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedCountry.flagEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 4),
                Text(
                  selectedCountry.dialCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                Container(
                  height: 24,
                  width: 1,
                  margin: const EdgeInsets.only(left: 6, right: 2),
                  color: cs.outlineVariant.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
      validator: (v) {
        if (validator != null) {
          return validator!(v);
        }
        if (v == null || v.trim().isEmpty) {
          return "Please enter mobile number";
        }
        final clean = v.trim().replaceAll(RegExp(r'\s+'), '');
        if (isIndia && clean.length != 10) {
          return "Enter a valid 10-digit mobile number";
        }
        if (!isIndia && clean.length < 7) {
          return "Enter a valid mobile number (min 7 digits)";
        }
        return null;
      },
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onSelected;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CountryCode> get _filteredCountries {
    if (_query.isEmpty) {
      return CountryCode.allCountries;
    }
    return CountryCode.allCountries.where((c) {
      final matchName = c.name.toLowerCase().contains(_query);
      final matchCode = c.dialCode.contains(_query);
      final matchIso = c.iso.toLowerCase().contains(_query);
      return matchName || matchCode || matchIso;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredCountries;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Select Country Code",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: "Search country name or code (+91, UAE...)",
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Popular countries when no search query
          if (_query.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                "POPULAR COUNTRIES",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: cs.primary,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: CountryCode.popularCountries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final c = CountryCode.popularCountries[index];
                  final isSelected = c.iso == widget.selectedCountry.iso;
                  return ChoiceChip(
                    label: Text("${c.flagEmoji} ${c.dialCode}"),
                    selected: isSelected,
                    onSelected: (_) => widget.onSelected(c),
                  );
                },
              ),
            ),
            const Divider(height: 18),
          ],

          // Countries List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      "No countries found for '$_query'",
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final country = filtered[index];
                      final isSelected = country.iso == widget.selectedCountry.iso;

                      return ListTile(
                        leading: Text(
                          country.flagEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              country.dialCode,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
                            ],
                          ],
                        ),
                        onTap: () => widget.onSelected(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
