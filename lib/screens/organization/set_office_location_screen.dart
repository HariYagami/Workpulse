import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:presenceiq/services/org_service.dart';
import 'package:presenceiq/theme/app_theme.dart';

class SetOfficeLocationScreen extends StatefulWidget {
  final String orgId;

  const SetOfficeLocationScreen({
    super.key,
    required this.orgId,
  });

  @override
  State<SetOfficeLocationScreen> createState() =>
      _SetOfficeLocationScreenState();
}

class _SetOfficeLocationScreenState extends State<SetOfficeLocationScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _resolvedAddress;
  double _radiusMeters = 100;

  bool _saving = false;
  bool _searching = false;
  bool _manualMode = false;
  bool _isEditing = false;
  bool _loadingExisting = true;

  // Saved state (from Firestore)
  double? _savedLatitude;
  double? _savedLongitude;
  double? _savedRadius;
  String? _savedAddress;

  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadExistingLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingLocation() async {
    try {
      final data = await OrgService().getOfficeLocation(widget.orgId);
      if (data != null) {
        setState(() {
          _savedLatitude = (data['latitude'] as num).toDouble();
          _savedLongitude = (data['longitude'] as num).toDouble();
          _savedRadius = (data['radiusMeters'] as num).toDouble();
          _savedAddress = data['address'] as String?;
          _loadingExisting = false;
        });
      } else {
        setState(() {
          _loadingExisting = false;
          _isEditing = true; // No location set yet, go straight to edit mode
        });
      }
    } catch (_) {
      setState(() {
        _loadingExisting = false;
        _isEditing = true;
      });
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _latitude = _savedLatitude;
      _longitude = _savedLongitude;
      _radiusMeters = _savedRadius ?? 100;
      _resolvedAddress = _savedAddress;
      if (_savedAddress != null) {
        _addressController.text = _savedAddress!;
      }
      if (_savedLatitude != null) {
        _latController.text = _savedLatitude!.toStringAsFixed(6);
        _lngController.text = _savedLongitude!.toStringAsFixed(6);
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _errorText = null;
      _latitude = null;
      _longitude = null;
      _resolvedAddress = null;
      _addressController.clear();
      _latController.clear();
      _lngController.clear();
    });
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _errorText = null;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'PresenceIQ/1.0',
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _latitude = double.parse(data[0]['lat']);
            _longitude = double.parse(data[0]['lon']);
            _resolvedAddress = data[0]['display_name'];
            _errorText = null;
          });
        } else {
          setState(() {
            _errorText = 'Address not found. Try a more specific address.';
            _latitude = null;
            _longitude = null;
          });
        }
      } else {
        setState(() => _errorText = 'Search failed. Please try again.');
      }
    } catch (_) {
      setState(() => _errorText = 'Network error. Check your connection.');
    } finally {
      setState(() => _searching = false);
    }
  }

  void _applyManualCoords() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      setState(() => _errorText = 'Enter valid numbers for both fields.');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setState(() => _errorText = 'Coordinates out of valid range.');
      return;
    }

    setState(() {
      _latitude = lat;
      _longitude = lng;
      _resolvedAddress =
          'Custom coordinates (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
      _errorText = null;
    });
  }

  Future<void> _saveLocation() async {
    if (_latitude == null || _longitude == null) return;
    setState(() => _saving = true);

    try {
      await OrgService().saveOfficeLocation(
        orgId: widget.orgId,
        latitude: _latitude!,
        longitude: _longitude!,
        radiusMeters: _radiusMeters,
      );

      // Update saved state
      setState(() {
        _savedLatitude = _latitude;
        _savedLongitude = _longitude;
        _savedRadius = _radiusMeters;
        _savedAddress = _resolvedAddress;
        _isEditing = false;
        _saving = false;
        _errorText = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Office location saved!',
                style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: AppColors.mintDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e',
                style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: const Color(0xFFA32D2D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.pastelBlueDark, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Office Location',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loadingExisting
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.pastelBlueDark,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Saved location card (shown when not editing) ──────
                  if (!_isEditing && _savedLatitude != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.mint.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.mintDark.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.mintDark.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  size: 20,
                                  color: AppColors.mintDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Office Location Set',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.mintDark,
                                      ),
                                    ),
                                    Text(
                                      'Tap Edit to update',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _startEditing,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.pastelBlueDark,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Edit',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 14),

                          // Address
                          if (_savedAddress != null) ...[
                            _savedInfoRow(
                              Icons.place_rounded,
                              'Address',
                              _savedAddress!,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Coordinates
                          _savedInfoRow(
                            Icons.my_location_rounded,
                            'Coordinates',
                            'Lat: ${_savedLatitude!.toStringAsFixed(6)}\nLng: ${_savedLongitude!.toStringAsFixed(6)}',
                          ),
                          const SizedBox(height: 10),

                          // Radius
                          _savedInfoRow(
                            Icons.radar_rounded,
                            'Check-in Radius',
                            '${_savedRadius!.toInt()} meters',
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Edit / Set form ──────────────────────────────────
                  if (_isEditing) ...[

                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.pastelBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.pastelBlueDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _manualMode
                                  ? 'Open Google Maps → long-press your office → copy coordinates shown at the top.'
                                  : 'Search by area or landmark (e.g. "Korattur, Chennai"). For exact spots, use manual mode.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.pastelBlueDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          _modeTab('Search Address', !_manualMode,
                              () => setState(() {
                                    _manualMode = false;
                                    _errorText = null;
                                  })),
                          _modeTab('Enter Manually', _manualMode,
                              () => setState(() {
                                    _manualMode = true;
                                    _errorText = null;
                                  })),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Search mode
                    if (!_manualMode) ...[
                      Text('Search by Area or Landmark',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              decoration:
                                  _inputDecoration('e.g. Korattur, Chennai'),
                              onSubmitted: (_) => _searchAddress(),
                              textInputAction: TextInputAction.search,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: ElevatedButton(
                              onPressed: _searching ? null : _searchAddress,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.pastelBlueDark,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _searching
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.search_rounded,
                                      color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              child: Text(_errorText!,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFFA32D2D))),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _manualMode = true;
                                _errorText = null;
                              }),
                              child: Text(
                                'Use manual entry →',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.pastelBlueDark,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    // Manual mode
                    if (_manualMode) ...[
                      Text('Latitude',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: _inputDecoration('e.g. 13.082700'),
                      ),
                      const SizedBox(height: 14),
                      Text('Longitude',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: _inputDecoration('e.g. 80.270700'),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _applyManualCoords,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text('Apply Coordinates',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.pastelBlueDark,
                            side: const BorderSide(
                                color: AppColors.pastelBlueDark),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(_errorText!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFA32D2D))),
                      ],
                    ],

                    // Resolved/preview card
                    if (_resolvedAddress != null && _latitude != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.mint.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.mintDark.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 15, color: AppColors.mintDark),
                                const SizedBox(width: 6),
                                Text('Ready to save',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mintDark)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_resolvedAddress!,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4)),
                            const SizedBox(height: 6),
                            Text(
                              'Lat: ${_latitude!.toStringAsFixed(6)},  '
                              'Lng: ${_longitude!.toStringAsFixed(6)}',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Radius slider
                    Row(
                      children: [
                        Text('Check-in Radius',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pastelBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_radiusMeters.toInt()} m',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pastelBlueDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Staff must be within this radius to clock in.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.pastelBlueDark,
                        inactiveTrackColor: AppColors.pastelBlue,
                        thumbColor: AppColors.pastelBlueDark,
                        overlayColor:
                            AppColors.pastelBlueDark.withOpacity(0.1),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _radiusMeters,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        onChanged: (val) =>
                            setState(() => _radiusMeters = val),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cancel + Save row
                    Row(
                      children: [
                        if (_savedLatitude != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : _cancelEditing,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                    color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              child: Text('Cancel',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_saving || _latitude == null)
                                ? null
                                : _saveLocation,
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white),
                                  )
                                : Text(
                                    _savedLatitude != null
                                        ? 'Update Location'
                                        : 'Save Office Location',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _savedInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.pastelBlueDark : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}