import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/driver_model.dart';
import '../../core/providers/app_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Form fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _licenceCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  XFile? _profilePhoto;
  XFile? _vehiclePhoto;

  int _currentStep = 0; // 0:info, 1:photos, 2:otp
  bool _isLoading = false;
  bool _otpSent = false;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();

  String _generatedDriverId = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _aadhaarCtrl.dispose();
    _licenceCtrl.dispose();
    _plateCtrl.dispose();
    _otpCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _generateDriverId() {
    final rand = Random();
    final digits = (rand.nextInt(9000) + 1000).toString();
    return 'AMB-$digits';
  }

  Future<void> _pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        if (isProfile) {
          _profilePhoto = picked;
        } else {
          _vehiclePhoto = picked;
        }
      });
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      setState(() => _currentStep = 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 1) {
      if (_profilePhoto == null || _vehiclePhoto == null) {
        _showSnack('Please upload both photos');
        return;
      }
      setState(() => _isLoading = true);
      await _sendOtp();
    }
  }

  Future<void> _sendOtp() async {
    final phone = '+91${_phoneCtrl.text.trim()}';
    await _authService.sendOtp(
      phone: phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpSent = true;
          _currentStep = 2;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnack('OTP error: $err');
      },
    );
  }

  Future<void> _verifyOtpAndRegister() async {
    if (_otpCtrl.text.trim().length != 6) {
      _showSnack('Enter 6-digit OTP');
      return;
    }
    setState(() => _isLoading = true);

    final verified = await _authService.verifyOtp(_otpCtrl.text.trim());
    if (!verified) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Invalid OTP. Please try again.');
      return;
    }

    // Generate driver ID
    _generatedDriverId = _generateDriverId();

    // Upload photos
    String profileUrl = '';
    String vehicleUrl = '';
    try {
      // Convert XFile to File for mobile, or skip for web
      if (!kIsWeb && _profilePhoto != null) {
        profileUrl = await _storageService.uploadProfilePhoto(
          io.File(_profilePhoto!.path),
          _generatedDriverId,
        );
      }
      if (!kIsWeb && _vehiclePhoto != null) {
        vehicleUrl = await _storageService.uploadVehiclePhoto(
          io.File(_vehiclePhoto!.path),
          _generatedDriverId,
        );
      }
    } catch (_) {
      // Photos optional if storage fails during demo
    }

    // Get FCM token
    final fcmToken = await NotificationService().getFcmToken() ?? '';

    // Build driver model
    final driver = DriverModel(
      driverId: _generatedDriverId,
      fullName: _nameCtrl.text.trim(),
      phone: '+91${_phoneCtrl.text.trim()}',
      aadhaar: _aadhaarCtrl.text.trim(),
      licence: _licenceCtrl.text.trim(),
      vehiclePlate: _plateCtrl.text.trim().toUpperCase(),
      profilePhotoUrl: profileUrl,
      vehiclePhotoUrl: vehicleUrl,
      fcmToken: fcmToken,
      createdAt: DateTime.now(),
    );

    // Save to Firestore
    await _firestoreService.saveDriver(driver);

    // Save driver ID locally
    await _authService.saveDriverId(_generatedDriverId);

    if (!mounted) return;

    // Update provider
    context.read<AppProvider>().setDriver(driver);

    setState(() => _isLoading = false);

    // Show success dialog
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.green, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.green, size: 56),
              const SizedBox(height: 16),
              Text('REGISTRATION COMPLETE', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text('Your Driver ID', style: AppTextStyles.bodySmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  _generatedDriverId,
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.primary,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Save this ID — you need it to login',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  child: Text('GO TO DASHBOARD', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.body),
        backgroundColor: AppColors.card,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildInfoPage(),
                  _buildPhotoPage(),
                  _buildOtpPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'ASTRA',
              style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text('DRIVER REGISTRATION', style: AppTextStyles.h3),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(
                color: i <= _currentStep
                    ? AppColors.primary
                    : AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Page 1: Info Form ─────────────────────────────

  Widget _buildInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Details', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'All information is stored encrypted',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildField(
              controller: _nameCtrl,
              label: 'FULL NAME',
              hint: 'As on Aadhaar card',
              icon: Icons.person_outline,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Name required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _phoneCtrl,
              label: 'PHONE NUMBER',
              hint: '10-digit mobile number',
              icon: Icons.phone_outlined,
              prefix: '+91  ',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) =>
                  (v?.length != 10) ? 'Enter valid 10-digit number' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _aadhaarCtrl,
              label: 'AADHAAR NUMBER',
              hint: '12-digit Aadhaar',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              validator: (v) =>
                  (v?.length != 12) ? 'Aadhaar must be 12 digits' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _licenceCtrl,
              label: 'DRIVER LICENCE NUMBER',
              hint: 'e.g. KA0120240012345',
              icon: Icons.credit_card_outlined,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Licence required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _plateCtrl,
              label: 'AMBULANCE NUMBER PLATE',
              hint: 'e.g. KA09A1234',
              icon: Icons.local_shipping_outlined,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Plate number required' : null,
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton('NEXT — UPLOAD PHOTOS', _nextStep),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: Text(
                  'Already registered? Login',
                  style: AppTextStyles.body.copyWith(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 2: Photos ────────────────────────────────

  Widget _buildPhotoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identity Verification', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            'Upload your photo and vehicle photo',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 28),
          _buildPhotoTile(
            label: 'PROFILE PHOTO',
            sublabel: 'Clear face photo',
            icon: Icons.person,
            file: _profilePhoto,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 16),
          _buildPhotoTile(
            label: 'AMBULANCE PHOTO',
            sublabel: 'Photo with vehicle & number plate visible',
            icon: Icons.local_shipping,
            file: _vehiclePhoto,
            onTap: () => _pickImage(false),
          ),
          const SizedBox(height: 32),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _buildPrimaryButton('SEND OTP & CONTINUE', _nextStep),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() => _currentStep = 0);
              _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.textSecond),
            label: Text(
              'Back',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecond),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile({
    required String label,
    required String sublabel,
    required IconData icon,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppColors.green : AppColors.cardBorder,
            width: file != null ? 1.5 : 1,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Display image based on platform
                    if (kIsWeb)
                      // Web: use Image.memory
                      FutureBuilder<Uint8List>(
                        future: file.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(snapshot.data!,
                                fit: BoxFit.cover);
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          );
                        },
                      )
                    else
                      // Mobile: use Image.memory from XFile
                      FutureBuilder<Uint8List>(
                        future: file.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(snapshot.data!,
                                fit: BoxFit.cover);
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          );
                        },
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'UPLOADED',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.textDim, size: 36),
                  const SizedBox(height: 10),
                  Text(label, style: AppTextStyles.label),
                  const SizedBox(height: 4),
                  Text(sublabel, style: AppTextStyles.caption),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'TAP TO SELECT',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Page 3: OTP ───────────────────────────────────

  Widget _buildOtpPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OTP Verification', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            'Sent to +91 ${_phoneCtrl.text.trim()}',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 32),
          // OTP field
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.display.copyWith(letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              hintText: '— — — — — —',
              hintStyle: AppTextStyles.h2.copyWith(
                color: AppColors.textDim,
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
          const SizedBox(height: 32),
          _isLoading
              ? Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Creating your ASTRA profile...',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                )
              : _buildPrimaryButton(
                  'VERIFY & REGISTER',
                  _verifyOtpAndRegister,
                ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _otpSent ? _sendOtp : null,
              child: Text(
                'Resend OTP',
                style: AppTextStyles.body.copyWith(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodySmall,
            prefixText: prefix,
            prefixStyle: AppTextStyles.body.copyWith(color: AppColors.accent),
            prefixIcon: Icon(icon, color: AppColors.textDim, size: 20),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label, style: AppTextStyles.button),
      ),
    );
  }
}
