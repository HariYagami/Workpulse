import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:presenceiq/screens/admin_dashboard.dart';
import 'package:presenceiq/services/org_service.dart';
import 'package:presenceiq/theme/app_theme.dart';


class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  // Accent color picker
  int _selectedColor = 0;
  final _colors = [
    [AppColors.pastelBlue, AppColors.pastelBlueDark],
    [AppColors.mint, AppColors.mintDark],
    [AppColors.lavender, AppColors.lavenderDark],
    [AppColors.peach, AppColors.peachDark],
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrg() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final orgId = await OrgService().createOrg(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );

      // Fetch the created org to pass to dashboard
      final org = await OrgService().getOrg(orgId);
      if (org == null) throw Exception('Failed to load organization.');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AdminDashboard(org: org),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('New Organization'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrgPreview(),
                const SizedBox(height: 28),
                _buildLabel('Organization name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. TechCorp Pvt Ltd',
                    prefixIcon: Icon(Icons.business_rounded,
                        size: 18, color: AppColors.textHint),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Description (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'What does this organization do?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel('Color theme'),
                const SizedBox(height: 10),
                _buildColorPicker(),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFF09595)),
                    ),
                    child: Text(_error!,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFFA32D2D))),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _createOrg,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Organization'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'An invite code will be generated automatically.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrgPreview() {
    final name = _nameCtrl.text.trim();
    final initials = name.isEmpty
        ? '?'
        : name.split(' ').length >= 2
            ? '${name.split(' ')[0][0]}${name.split(' ')[1][0]}'.toUpperCase()
            : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();

    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _colors[_selectedColor][0],
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _colors[_selectedColor][1],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? 'Your Organization' : name,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: name.isEmpty
                  ? AppColors.textHint
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Row(
      children: List.generate(_colors.length, (i) {
        final selected = _selectedColor == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            width: selected ? 44 : 36,
            height: selected ? 44 : 36,
            decoration: BoxDecoration(
              color: _colors[i][0],
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: _colors[i][1], width: 2)
                  : null,
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                    size: 18, color: _colors[i][1])
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}