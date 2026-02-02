import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Address autocomplete widget using Google Places API
/// Parses address components into separate fields
class AddressAutocomplete extends StatefulWidget {
  final String? initialValue;
  final Function(AddressComponents) onAddressSelected;
  final String? googleApiKey;
  final String hintText;
  final bool enabled;

  const AddressAutocomplete({
    super.key,
    this.initialValue,
    required this.onAddressSelected,
    this.googleApiKey,
    this.hintText = 'Enter address...',
    this.enabled = true,
  });

  @override
  State<AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showOverlay = false;
  Timer? _debounce;
  OverlayEntry? _overlayEntry;

  // Default API key - should be configured in app settings
  String get _apiKey => widget.googleApiKey ?? 'YOUR_GOOGLE_API_KEY';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue ?? '';
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AddressAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _predictions.isNotEmpty) {
      _showOverlayWidget();
    } else if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.length < 3) {
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
      _hideOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchPlaces(value);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (_apiKey == 'YOUR_GOOGLE_API_KEY') {
      // Fallback to basic suggestions if no API key
      _showBasicSuggestions(query);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&types=address'
        '&components=country:us'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions = (data['predictions'] as List)
                .map((p) => PlacePrediction.fromJson(p))
                .toList();
          });

          if (_predictions.isNotEmpty && _focusNode.hasFocus) {
            _showOverlayWidget();
          }
        } else {
          _showBasicSuggestions(query);
        }
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      _showBasicSuggestions(query);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showBasicSuggestions(String query) {
    // Basic fallback - just show current input as an option
    setState(() {
      _predictions = [
        PlacePrediction(
          placeId: 'manual',
          description: query,
          mainText: query,
          secondaryText: 'Use as entered',
        ),
      ];
    });

    if (_focusNode.hasFocus) {
      _showOverlayWidget();
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    _hideOverlay();
    _controller.text = prediction.description;

    if (prediction.placeId == 'manual') {
      // Manual entry - try to parse
      final components = _parseManualAddress(prediction.description);
      widget.onAddressSelected(components);
      return;
    }

    if (_apiKey == 'YOUR_GOOGLE_API_KEY') {
      final components = _parseManualAddress(prediction.description);
      widget.onAddressSelected(components);
      return;
    }

    // Get place details for full address components
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${prediction.placeId}'
        '&fields=address_components,formatted_address,geometry'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final components = AddressComponents.fromGooglePlace(data['result']);
          _controller.text = components.formattedAddress;
          widget.onAddressSelected(components);
        }
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      // Fallback to manual parsing
      final components = _parseManualAddress(prediction.description);
      widget.onAddressSelected(components);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  AddressComponents _parseManualAddress(String address) {
    // Basic parsing for manual entry
    // Expected formats: "123 Main St, City, ST 12345" or "123 Main St, City, State 12345"
    final parts = address.split(',').map((s) => s.trim()).toList();

    String street = '';
    String city = '';
    String state = '';
    String zipCode = '';

    if (parts.isNotEmpty) {
      street = parts[0];
    }

    if (parts.length >= 2) {
      city = parts[1];
    }

    if (parts.length >= 3) {
      // Last part might be "ST 12345" or "State 12345" or just "12345"
      final lastPart = parts.last;
      final stateZipMatch = RegExp(r'^([A-Z]{2})\s*(\d{5}(-\d{4})?)$').firstMatch(lastPart);

      if (stateZipMatch != null) {
        state = stateZipMatch.group(1)!;
        zipCode = stateZipMatch.group(2)!;
      } else {
        // Try to extract zip from end
        final zipMatch = RegExp(r'(\d{5}(-\d{4})?)$').firstMatch(lastPart);
        if (zipMatch != null) {
          zipCode = zipMatch.group(1)!;
          state = lastPart.replaceAll(zipCode, '').trim();
        } else {
          state = lastPart;
        }
      }

      // If we have 4+ parts, city might be in the middle
      if (parts.length >= 4) {
        city = parts[parts.length - 2];
      }
    }

    return AddressComponents(
      streetAddress: street,
      city: city,
      state: state,
      zipCode: zipCode,
      formattedAddress: address,
    );
  }

  void _showOverlayWidget() {
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: context.findRenderObject() != null
            ? (context.findRenderObject() as RenderBox).size.width
            : 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      prediction.placeId == 'manual'
                          ? Icons.edit_location
                          : Icons.location_on,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    title: Text(
                      prediction.mainText,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: prediction.secondaryText.isNotEmpty
                        ? Text(
                            prediction.secondaryText,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          )
                        : null,
                    onTap: () => _selectPrediction(prediction),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showOverlay = true);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_showOverlay) {
      setState(() => _showOverlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.location_on_outlined),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _predictions = []);
                        _hideOverlay();
                      },
                    )
                  : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        onChanged: _onTextChanged,
        onTap: () {
          if (_predictions.isNotEmpty) {
            _showOverlayWidget();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// Model for Google Place prediction
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structured['main_text'] ?? json['description'] ?? '',
      secondaryText: structured['secondary_text'] ?? '',
    );
  }
}

/// Parsed address components
class AddressComponents {
  final String streetAddress;
  final String? streetAddress2;
  final String city;
  final String state;
  final String zipCode;
  final String? country;
  final String formattedAddress;
  final double? latitude;
  final double? longitude;

  AddressComponents({
    required this.streetAddress,
    this.streetAddress2,
    required this.city,
    required this.state,
    required this.zipCode,
    this.country,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
  });

  factory AddressComponents.fromGooglePlace(Map<String, dynamic> place) {
    final components = place['address_components'] as List? ?? [];
    final geometry = place['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    String streetNumber = '';
    String route = '';
    String city = '';
    String state = '';
    String zipCode = '';
    String country = '';

    for (final component in components) {
      final types = (component['types'] as List).cast<String>();
      final value = component['long_name'] ?? '';
      final shortValue = component['short_name'] ?? value;

      if (types.contains('street_number')) {
        streetNumber = value;
      } else if (types.contains('route')) {
        route = value;
      } else if (types.contains('locality')) {
        city = value;
      } else if (types.contains('administrative_area_level_1')) {
        state = shortValue; // Use abbreviation for state
      } else if (types.contains('postal_code')) {
        zipCode = value;
      } else if (types.contains('country')) {
        country = shortValue;
      }
    }

    final streetAddress = '$streetNumber $route'.trim();

    return AddressComponents(
      streetAddress: streetAddress,
      city: city,
      state: state,
      zipCode: zipCode,
      country: country,
      formattedAddress: place['formatted_address'] ?? streetAddress,
      latitude: location?['lat']?.toDouble(),
      longitude: location?['lng']?.toDouble(),
    );
  }

  @override
  String toString() {
    return '$streetAddress, $city, $state $zipCode';
  }
}

/// Simple address form that uses autocomplete
class AddressForm extends StatefulWidget {
  final AddressComponents? initialAddress;
  final Function(AddressComponents) onAddressChanged;
  final String? googleApiKey;
  final bool enabled;

  const AddressForm({
    super.key,
    this.initialAddress,
    required this.onAddressChanged,
    this.googleApiKey,
    this.enabled = true,
  });

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late TextEditingController _streetController;
  late TextEditingController _street2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController(text: widget.initialAddress?.streetAddress ?? '');
    _street2Controller = TextEditingController(text: widget.initialAddress?.streetAddress2 ?? '');
    _cityController = TextEditingController(text: widget.initialAddress?.city ?? '');
    _stateController = TextEditingController(text: widget.initialAddress?.state ?? '');
    _zipController = TextEditingController(text: widget.initialAddress?.zipCode ?? '');
  }

  void _onAddressSelected(AddressComponents components) {
    setState(() {
      _streetController.text = components.streetAddress;
      _cityController.text = components.city;
      _stateController.text = components.state;
      _zipController.text = components.zipCode;
    });
    widget.onAddressChanged(components);
  }

  void _notifyChange() {
    widget.onAddressChanged(AddressComponents(
      streetAddress: _streetController.text,
      streetAddress2: _street2Controller.text.isNotEmpty ? _street2Controller.text : null,
      city: _cityController.text,
      state: _stateController.text,
      zipCode: _zipController.text,
      formattedAddress: '${_streetController.text}, ${_cityController.text}, ${_stateController.text} ${_zipController.text}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Autocomplete search
        AddressAutocomplete(
          initialValue: _streetController.text,
          onAddressSelected: _onAddressSelected,
          googleApiKey: widget.googleApiKey,
          hintText: 'Search address...',
          enabled: widget.enabled,
        ),
        const SizedBox(height: 12),

        // Street address (editable)
        TextFormField(
          controller: _streetController,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Street Address',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),

        // Street address 2
        TextFormField(
          controller: _street2Controller,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Apt, Suite, Unit (optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),

        // City, State, Zip in a row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _cityController,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),

            // State
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _stateController,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  labelText: 'State',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),

            // Zip
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _zipController,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  labelText: 'ZIP Code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 10,
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _streetController.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }
}
