import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../models/business.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';

/// MerchantRegController manages multi-step merchant registration form state
/// across Steps 1 to 4 with resume-to-Step-2 capability.
class MerchantRegController extends ChangeNotifier {
  // -------------------------------------------------------------
  // Step 1: Owner Basics
  // -------------------------------------------------------------
  String fullName = '';
  String dob = '1990-05-14';
  String phone = '';
  String email = '';
  String password = '';
  bool isOtpVerified = false;

  // -------------------------------------------------------------
  // Step 2: Business Information
  // -------------------------------------------------------------
  String businessName = '';
  String category = 'cafe'; // Default canonical slug
  String bio = '';
  String municipality = 'San Jose de Buenavista, Antique';
  String address = 'Corner Tradisyonal St., Brgy. San Pedro';
  String contactPhone = '';
  String hours = 'Mon – Sun: 7:00 AM – 9:00 PM';
  double lat = demoShopLat;
  double lng = demoShopLng;
  bool isLocating = false;
  String? locationMessage;

  // -------------------------------------------------------------
  // Step 3: Permits & Verification Documents
  // -------------------------------------------------------------
  String? dtiFileName;
  String? dtiUrl;
  bool uploadingDti = false;

  String? birFileName;
  String? birUrl;
  bool uploadingBir = false;

  String? mayorFileName;
  String? mayorUrl;
  bool uploadingMayor = false;

  String? validIdFileName;
  String? validIdUrl;
  bool uploadingValidId = false;

  // -------------------------------------------------------------
  // Submission State
  // -------------------------------------------------------------
  bool isSubmitting = false;
  String? submitError;
  Business? createdBusiness;

  /// Resume state for returning merchant with existing profile but no business row
  void populateFromProfile(Profile profile, User? user) {
    if (profile.fullName != null && profile.fullName!.isNotEmpty) {
      fullName = profile.fullName!;
    }
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      phone = profile.phone!;
      contactPhone = profile.phone!;
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      email = user.email!;
    }
    isOtpVerified = true;
    notifyListeners();
  }

  /// Request current GPS fix, falling back to demo shop coordinates
  Future<void> useCurrentLocation() async {
    isLocating = true;
    locationMessage = null;
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = position.latitude;
        lng = position.longitude;
        locationMessage = 'Using GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
      } else {
        // Fallback to demo shop
        lat = demoShopLat;
        lng = demoShopLng;
        locationMessage = 'Permission denied; using demo shop location';
      }
    } catch (_) {
      // Fallback gracefully
      lat = demoShopLat;
      lng = demoShopLng;
      locationMessage = 'GPS timeout; using demo shop location';
    } finally {
      isLocating = false;
      notifyListeners();
    }
  }

  /// Pick document file and upload to Supabase Storage under `merchant-docs/<uid>/`.
  /// Never blocks progress on failure.
  Future<void> pickAndUploadDocument({
    required String docType, // 'dti', 'bir', 'mayor', 'valid_id'
    required String userId,
    required DataService dataService,
  }) async {
    try {
      _setDocUploading(docType, true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _setDocUploading(docType, false);
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes != null && userId.isNotEmpty) {
        try {
          final url = await dataService.uploadMerchantPermit(
            ownerId: userId,
            fileName: '${docType}_$fileName',
            fileBytes: fileBytes,
          );
          _setDocSuccess(docType, fileName, url);
        } catch (_) {
          // Upload failed; record filename locally anyway so demo user is never blocked
          _setDocSuccess(docType, fileName, null);
        }
      } else {
        _setDocSuccess(docType, fileName, null);
      }
    } catch (_) {
      _setDocUploading(docType, false);
    }
  }

  void _setDocUploading(String type, bool value) {
    switch (type) {
      case 'dti':
        uploadingDti = value;
        break;
      case 'bir':
        uploadingBir = value;
        break;
      case 'mayor':
        uploadingMayor = value;
        break;
      case 'valid_id':
        uploadingValidId = value;
        break;
    }
    notifyListeners();
  }

  void _setDocSuccess(String type, String fileName, String? url) {
    switch (type) {
      case 'dti':
        dtiFileName = fileName;
        dtiUrl = url;
        uploadingDti = false;
        break;
      case 'bir':
        birFileName = fileName;
        birUrl = url;
        uploadingBir = false;
        break;
      case 'mayor':
        mayorFileName = fileName;
        mayorUrl = url;
        uploadingMayor = false;
        break;
      case 'valid_id':
        validIdFileName = fileName;
        validIdUrl = url;
        uploadingValidId = false;
        break;
    }
    notifyListeners();
  }

  /// Submit registration: creates merchant auth user if not yet logged in,
  /// then creates the unverified business row.
  Future<bool> submitRegistration({
    required AuthService authService,
    required DataService dataService,
  }) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      String? uid = authService.currentUserId;

      // If not yet authenticated, sign up as merchant
      if (uid == null || uid.isEmpty) {
        final authRes = await authService.signUpMerchant(
          email: email.trim(),
          password: password,
          fullName: fullName.trim(),
          phone: phone.trim(),
        );
        uid = authRes.user?.id;
      }

      if (uid == null || uid.isEmpty) {
        throw Exception('Could not determine merchant user ID');
      }

      final newBusiness = Business(
        id: '', // Generated by Supabase Postgres
        ownerId: uid,
        name: businessName.trim().isEmpty ? 'Kape Tahanan Specialty Brews' : businessName.trim(),
        category: category,
        bio: bio.trim().isEmpty
            ? 'Hand-roasted heirloom Philippine coffee blends, slow drip brews, and homemade native pastries.'
            : bio.trim(),
        address: address.trim().isEmpty ? 'Corner Tradisyonal St., Brgy. San Pedro' : address.trim(),
        phone: contactPhone.trim().isEmpty ? phone.trim() : contactPhone.trim(),
        hours: hours.trim().isEmpty ? 'Mon – Sun: 7:00 AM – 9:00 PM' : hours.trim(),
        lat: lat,
        lng: lng,
        radiusMeters: 1500.0,
        rating: 4.8,
        verified: false, // Explicitly false per spec until Waiting auto-verifies
        coverUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24',
        createdAt: DateTime.now(),
      );

      final created = await dataService.createBusiness(newBusiness);
      createdBusiness = created;
      isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      isSubmitting = false;
      submitError = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }
}
