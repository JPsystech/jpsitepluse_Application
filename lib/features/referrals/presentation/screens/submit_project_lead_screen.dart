import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_event.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_state.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/referral_terms_sheet.dart';
import 'package:sitepulse_engineer/shared/models/country_code.dart';
import 'package:sitepulse_engineer/shared/widgets/country_code_phone_field.dart';

class SubmitProjectLeadScreen extends StatelessWidget {
  final ReferralBloc? bloc;

  const SubmitProjectLeadScreen({
    super.key,
    this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: const _SubmitProjectLeadScreenContent(),
      );
    }

    try {
      final existing = context.read<ReferralBloc>();
      return BlocProvider.value(
        value: existing,
        child: const _SubmitProjectLeadScreenContent(),
      );
    } catch (_) {
      return BlocProvider(
        create: (_) => ReferralBloc()..add(const LoadReferralDataRequested()),
        child: const _SubmitProjectLeadScreenContent(),
      );
    }
  }
}

class _SubmitProjectLeadScreenContent extends StatefulWidget {
  const _SubmitProjectLeadScreenContent();

  @override
  State<_SubmitProjectLeadScreenContent> createState() =>
      _SubmitProjectLeadScreenContentState();
}

class _SubmitProjectLeadScreenContentState
    extends State<_SubmitProjectLeadScreenContent> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactMobileController = TextEditingController();
  CountryCode _selectedCountry = CountryCode.india;
  final _contactEmailController = TextEditingController();
  final _siteNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _remarksController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _clientNameController.dispose();
    _contactPersonController.dispose();
    _contactMobileController.dispose();
    _contactEmailController.dispose();
    _siteNameController.dispose();
    _siteAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _estimatedValueController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location permissions are permanently denied."),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("GPS Coordinates fetched successfully!"),
          backgroundColor: Color(0xFF047857),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch location: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final contactEmail = _contactEmailController.text.trim().toLowerCase();
    if (contactEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Contact email address is required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final estVal = double.tryParse(_estimatedValueController.text.trim());

    final fullContactMobile = _contactMobileController.text.trim().isEmpty
        ? null
        : "${_selectedCountry.dialCode} ${_contactMobileController.text.trim()}";

    context.read<ReferralBloc>().add(
          SubmitProjectInquiryRequested(
            clientName: _clientNameController.text.trim(),
            contactPerson: _contactPersonController.text.trim().isEmpty
                ? null
                : _contactPersonController.text.trim(),
            contactMobile: fullContactMobile,
            contactEmail: contactEmail,
            siteName: _siteNameController.text.trim().isEmpty
                ? null
                : _siteNameController.text.trim(),
            siteAddress: _siteAddressController.text.trim().isEmpty
                ? null
                : _siteAddressController.text.trim(),
            city: _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            state: _stateController.text.trim().isEmpty
                ? null
                : _stateController.text.trim(),
            latitude: _latitude,
            longitude: _longitude,
            estimatedValue:estVal,
            remarks: _remarksController.text.trim().isEmpty
                ? null
                : _remarksController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<ReferralBloc, ReferralState>(
      listener: (context, state) {
        if (state is ReferralLoaded) {
          if (state.submitSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.submitSuccessMessage!),
                backgroundColor: const Color(0xFF047857),
              ),
            );
            Navigator.of(context).pop();
          } else if (state.submitErrorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.submitErrorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (state is ReferralError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting =
            state is ReferralLoaded && state.isSubmitting;

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            title: const Text("Submit Project Lead"),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Client Info Section
                    Text(
                      "Client / Organization Information",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: "Client / Company Name *",
                        prefixIcon: Icon(Icons.business_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please enter client or company name";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(
                        labelText: "Contact Person Name",
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    CountryCodePhoneField(
                      controller: _contactMobileController,
                      selectedCountry: _selectedCountry,
                      onCountryChanged: (c) {
                        setState(() {
                          _selectedCountry = c;
                        });
                      },
                      labelText: "Contact Mobile *",
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please enter mobile number";
                        }
                        final clean = v.trim().replaceAll(RegExp(r'\s+'), '');
                        if (_selectedCountry.iso == 'IN' && clean.length != 10) {
                          return "Enter a valid 10-digit mobile number";
                        }
                        if (_selectedCountry.iso != 'IN' && (clean.length < 7 || clean.length > 15)) {
                          return "Enter a valid mobile number (7-15 digits)";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _contactEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Contact Email *",
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: "client@company.com",
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please enter contact email";
                        }
                        final clean = v.trim().toLowerCase();
                        final emailRegex = RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
                        if (!emailRegex.hasMatch(clean)) {
                          return "Enter a valid email (e.g. name@company.com)";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Site Information Section
                    Text(
                      "Site & Location Details",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _siteNameController,
                      decoration: const InputDecoration(
                        labelText: "Site / Project Name",
                        prefixIcon: Icon(Icons.apartment_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _siteAddressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Site Address",
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: "City",
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: "State",
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // GPS Location Capture Card
                    _buildGpsCard(),
                    const SizedBox(height: 24),

                    // Estimated Value & Remarks
                    Text(
                      "Deal & Business Details",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _estimatedValueController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Estimated Project Value (₹)",
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        hintText: "e.g. 500000",
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Remarks & Project Scope",
                        hintText:
                            "Describe project requirements, scope of work, timeline...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms & Conditions Agreement
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _agreedToTerms
                              ? cs.primary.withValues(alpha: 0.4)
                              : cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (val) {
                                setState(() {
                                  _agreedToTerms = val ?? false;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface,
                                      height: 1.35,
                                    ),
                                children: [
                                  const TextSpan(
                                    text: "I confirm this is a genuine lead & agree to ",
                                  ),
                                  TextSpan(
                                    text: "Project Lead Terms & Conditions",
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        ReferralTermsSheet.show(
                                          context,
                                          type: ReferralTermsType.projectLead,
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (isSubmitting || !_agreedToTerms) ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Submit Project Lead",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGpsCard() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.my_location_rounded,
                color: cs.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Site GPS Coordinates",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  _latitude != null && _longitude != null
                      ? "${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}"
                      : "Not captured yet",
                  style: TextStyle(
                    fontSize: 11,
                    color: _latitude != null ? const Color(0xFF047857) : cs.onSurfaceVariant,
                    fontWeight: _latitude != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (_latitude != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: () {
                setState(() {
                  _latitude = null;
                  _longitude = null;
                });
              },
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
            icon: _isFetchingLocation
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Icon(Icons.gps_fixed_rounded, size: 14),
            label: Text(
              _latitude != null ? "Update" : "Capture",
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
